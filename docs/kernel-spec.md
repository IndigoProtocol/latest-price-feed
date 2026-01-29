# Kernel Spec :: Latest Price Feed

This document provides the specification of the kernel, ie "on-chain" component, of the Latest Price Feed application.

## Context

There are two existing protocols: Indigo and Orcfax. Orcfax is an oracle, publisher of data, while Indigo Protocol is
DeFi app, and a consumer of data. The objective is to have the data published by Orcfax consumable by Indigo Protocol.
The format of data Orcfax publishes does not match the format required as input for Indigo Protocol. The role of the Latest
Price Feed application is to resolve this.

### Orcfax

Orcfax publishes data on-chain in the form of **Fact statements**. These are consumable by Plutus validators via
reference inputs. The datum has the following form:

```aiken
pub type Datum<t> {
  statement: Statement<t>,
  context: Data,
}

pub type Statement<t> {
  feed_id: ByteArray,
  created_at: Int,
  body: t,
}
```

The `context` can be safely ignored by consumers and is not relevant here.

[Source](https://github.com/orcfax/orcfax-aiken/blob/main/lib/orcfax/types.ak)

In the case of price feed data, the body type is:

```aiken
pub type Rational {
  num: Int,
  denom: Int,
}
```

[Source](https://docs.orcfax.io/consume#coercing-the-body)

Details of steps a validator must take to safely consume a fact statements are given in the documentation linked. These
include: finding a validity token in the value of the UTXO, verifying the feed id and created at fields.

### Indigo

The Indigo Protocol consumes price feed data via the datum of a reference input. The reference input is identified by
the presence of an NFT (that can be set arbitrarily). The datum is of the following form

```aiken
Datum {
  price: OnChainDecimal,
  expiration: Int,
}

OnChainDecimal {
  get_on_chain_int: 1_500_000 // = 1.500000
}
```

The `price` is expressed as an (albeit nested) int. The effective position of the decimal place is hard-coded in the
validator consuming the data.

## Requirements

Ultimate goal: Facilitate the consumption by Indigo Protocol of data derived from Orcfax Fact Statements.

Assumptions:

- The application includes a component consumable by the Indigo Protocol. That is, a UTXO at tip with an NFT and datum
  of the prescribed format. We say **update** to refer to a transaction in which newer Orcfax Fact Statments are used to
  "update" this datum.
- There is a distinct "instance" per price feed required by Indigo Protocol.
- Each instance has an "init" action, after which it is "running". We use this to distinguish between "configurable at
  init" and "configurable at runtime".

Musts:

1. Updates are near immediate.
1. Updates are permissioned by transaction signature.
1. Hot keys are rotated. In particular, the key permissioned to update is rotated.
1. The rotation is administered by an [Aicone](https://github.com/SundaeSwap-finance/aicone) component, which itself is
   also configurable at runtime via the same administer action.
1. Feed data is configured at init to correspond to one of the following: a single Orcfax Fact Statement; a reciprocal;
   a product of two.  
   For example, Orcfax provides, say, `ADA-USD` and `BTC-USD` feed. Then, it must be possible to produce a LPF for
   `ADA-USD`, `USD-ADA`, and `ADA-BTC`.
1. On init, there is a specified `expiration_bias`, the time from a Fact statement' `created_at` and the resulting
   `expiration`. That is, on each update `expiration = created_at + expiration_bias`.
1. Sanity checks enforced on-chain:
   1. No non-zero output price
   1. No non-zero denominator of input

Non-requirements:

1. No restrictions on staking

## Design Overview

### Validators

The app consists of a single **seeded** validator, hereafter **main**, which can be executed in precisely mint and spend
purpose. By seeded, we mean that on init some UTXO specified in the validator parameters must be spent, and in doing we
guarantee uniqueness of the instance's validator (and so also script hash).

In the following "own" refers to belonging to the instances. For example: "own token" refers to a token with hash (aka
policy ID) of the instance; "own address" refers to an address with payment credentials corresponding to the instance
_etc_. In the present case, it is enforced that own address is unstaked.

### UTXOs

An instance, while running, has on-chain state of two UTXOs:

- Price - A reference input for the Indigo Protocol to consume price data.
- Aux - Facilitates the persistence of state on-chain required for the app to function.

Each UTXO can be identified by the presence of an NFT, both own tokens. At any point in time the UTXOs have the same
address, an own address.

### Lifecycle

All instances are instantiated by the init. In an init the Price and Aux UTXOs are created. This involves minting the
NFTs.

An instance runs in a singular stage for its lifecycle. This stage is a fixed point under the two transactions.

1. Update: the Price and Aux are both spent together with Orcfax Fact Statement(s) as reference inputs.
1. Administer: the Price is spent (Aux is not).

There is one end of life transaction, a burn. In a burn, the Price and Aux are spent, and NFTs burnt. This is included
for tidying up, and can be disabled in production if desired.

### Tokens

To create an NFT it is sufficient to specify the asset name, since each instance has a unique hash.

```ini
price="price"
aux="aux"
```

## Spec

### Main

#### Types

```aiken
use sundae/multisig.{MultisigScript}

/// Posix time in milliseconds, as it appears in validity range for example.
type Timestamp = Int

/// Seed
type Params = OutputReference

/// Datum
/// This definition is in part motivated to coax aiken
/// to give us an ameanable cbor.
/// The `Aux` fields are referred to as `(created_ats, updater, admin)`
type Datum<t> {
  Price(WrappedInt, Timestamp)
  Aux(t, VerificationKeyHash, MultisigScript)
}

type WrappedInt {
  int : Int,
}

/// Note that by defining the type as above,
/// as CBOR `Price` serializes as though it is defined as:

type PriceDatum {
  price : WrappedInt
  expire_at : Int,
}

/// Redeemer.
/// Defer(own_index, aux_index)
/// Update(own_index, price_in, price_out)
type Redeemer {
  Defer(Int, Int)
  Update(Int, Int, Int)
  Administer
}
```

#### Logic

##### IO

Transactions are constrained in part by the conditions of own inputs and outputs. We specify the logic for own inputs
and outputs here.

An Aux Input:

- ai.0: Value contains aux NFT.

A Price Output:

- po.0: Address is own address
- po.1: Value is Ada and price NFT.
- po.2: Datum is inlined `Price`
- po.3: Script ref is none.

An Aux Output:

- ao.0: Address is own address
- ao.1: Value is Ada and aux NFT.
- ao.2: Datum is inlined `Aux`
- ao.3: Script ref is none.

We make accommodation for inputs being lexicographically ordered (and so difficult to know indicies precisely prior to
transaction balancing), while utilizing that output order can be specified with relative ease. The term "input from"
indicates that the index of the input is "this or after this". This makes it easier to build valid transactions, where
the balancing step may insert additional inputs, after setting the redeemer.

Outputs are expected in the order specified unless stated otherwise.

At init, the datums are set to their "zero value". The Price datum zero is `Price(WrappedInt(0), 0)`. The Aux datum zero
will have `created_ats` set to `0` as applicable.

##### Mint Purpose

The constraints enforce that a transaction involving own is either the init, or the burn of an instance. As the script
is seeded, the init is unique. As the init is unique so to is the burn.

- mint.0 : Own mint has precisely two entries.
- mint.1 : The names are precisely as in tokens.
- mint.2 : The amounts are either both 1 or both -1.
- mint.3 : If amounts are 1, then
    - mint.3.0 : Seed (params) is spend
    - mint.3.1 : Find Price output with "zero" datum.
    - mint.3.2 : Find Aux output with "zero" datum.

##### Spend Purpose

If datum, redeemer are `(Price, Defer(own_index, aux_index)`,

- defer.0 : Find own input from `own_index`. Derive own hash.
- defer.0 : Find Aux input from `aux_index` (via NFT).

If datum, redeemer are `(Aux, Update(own_index, price_in, price_out))`

- update.0 : Find own input from `own_index`. Derive own hash.
- update.1 : Parse Price in from inputs (starting from index `price_in`)
- update.2 : Parse Price out from outputs (precisely `price_out`)
- update.3 : Parse Aux out (immediately after `price_out`)
- update.4 : Price out aligns with referenced Fact Statement(s)
- update.5 : Update is newer

If datum, redeemer are `(Aux, Administer)`

- admin.0 : `admin` (Aicone) is satisfied.
- admin.1 : Either:
  - admin.1.0 : Continuing output has only modified `updater` and `admin`
  - admin.1.1 : No `Aux` token is output
- admin.2 : Own mint is non-empty

All other datum, redeemer pairs fail.

All constraints imposed on the spend of Price are deferred to execution of Aux. In these cases, the validator verifies
that the transaction also spends Aux.
As a consequence, Aux must always verify the outcome of Price, including verifying its non-inclusion where appropriate.

The `Administer` redeemer is used to spend in a burn transaction.

#### Functions

##### Price Align

The expression of price in Orcfax is different to that of Indigo Protocol. We should not expect equality, but instead
bound the divergence between the two. Orcfax price is of the form `(num, denom)`; the Indigo Protocol price is of the
form `(sig, exp)` (significand, exponent). Note that the `exp` is fixed at compile time. We split the handling in terms
of the different feed functions: single, reciprocal, product.

For a single

```aiken
fn single( num : Int, denom : Int, sig : Int ) {
    let orcfax = num * pow(10, exp)
    let indigo = sig * denom
    (orcfax - threshold < indigo && indigo < orcfax + threshold)
}
```

For a reciprocal

```aiken
fn reciprocal( num : Int, denom : Int, sig : Int ) {
    single(denom, num, sig)
}
```

For a product, suppose we have Orcfax feeds A-B, and A-C, with Indigo expressing the price B-C

```aiken
fn product( num_0: Int, denom_0 : Int, num_1 : Int, denom_1 : Int, sig : Int ) {
    single (num_0 * denom_1, denom_0 * num_1, sig)
}
```

Warning! Care must be taken to ensure that the formula is invoked as intended. A healthy serving of test vectors must be
passing as a sanity check before use.

We can also place the requested sanity check at this point:

```aiken
fn single( num : Int, denom : Int, sig : Int ) {
    expect num > 0
    expect denom > 0
    let orcfax = num * pow(10, exp)
    let indigo = sig * denom
    (orcfax - threshold < indigo && indigo < orcfax + threshold)
}
```

#### Newer

In an update the continuing price must be newer. In a one fact statement case, it is sufficient to verify that

```aiken
expect cont_datum == created_at + expiration_bias
expect cont_datum.expiration > prev_datum.expiration
```

In the case of product, then there is a decision as to what the `cont_datum.expiration` should be. The other fact
statement's `created_at` is recorded in the aux datum. On an update, at least one must be later.

TODO :: TBD.

## Design choices

We persist data between transactions via inline datums. Inline datums are the most convenient way to persist data from
the one transaction to another. Moreover, an inline datum is required to make the data consumable by Indigo Protocol.
However the format (type) of the datum for Indigo Protocol is fixed and it cannot accommodate the auxiliary data
required to ensure "latest". That is why we have a second auxiliary datum. The design has two UTXOs maintaining state in
a coupled manner.

Coupling the spend of UTXOs on Cardano like this is awkward for two primary reasons:

1. The unpacked context of the validator does not include own hash. Instead, the validator must establish it from
   finding its own input from the inputs. Worst still, the context provides the `output_reference` rather than, say, the
   input index. That is, without additional hints from, say, the redeemer, the validator must at least partially unpack
   each `input.output_reference`, and on match continue unpack `input.output.address.payment_credential`, and only then,
   establish `own_hash`.
2. The validator is executed once per input, rather than once per transaction, or once for a spend.

In both cases cf with mint purpose which is executed once per transaction and has own hash from context.

The design optimises for the most common transaction, the update. This is the transaction we primarily consider.

We rule out the use of non-spend purpose for the transactions for the running instance (ie update, and administer).
Coupling requires that at least one validator execution verifies the execution of another within the transaction, in
many cases more than one. In general there are many different ways this can be achieved. In the current case, we have at
least two spends of the validator(s) in an update. It is not necessary, and nor does it seem prudent to employ a
"withdraw 0" hack or similar.

We rule out the use of more than one validator. It would be possible to couple via two distinct validators: one for
price and another for aux. Coupling distinct validators requires at least one direction to be established after
compiling. For example:

- the price validator has the aux hash "hard coded" (ie known at compile time).
- the aux validator has the price validator on init and is a fixed point of its datum.

Advantages:

- Price knows aux hash. It can skip finding out own hash, which it does only to verify Aux hash.
- Aux hash knows own hash, and price hash without traversing inputs.

Some disadvantages:

- The init step(s) is a little more complicated.
- The tooling for a compile time dependency is not first class (see
  (discussion)[https://github.com/aiken-lang/aiken/discussions/676]).
- Another disadvantage is that the cost of requiring two smaller scripts is likely greater than one larger one (... at
  least this my hunch).

These disadvantages seem relative small and this is probably worth considering further, resources permitting.

We defer the core logic to the Aux execution. We wish to reduce duplicating logic in the interests of both cost and
clarity. It is not obvious the optimal division of labor is between the two executions of validator in an update. The
coupling logic must verify that the "other" UTXO is valid. Specifically in that the UTXO contains the expected NFT. Thus
the coupling logic must either inspect the correct input for the NFT, or the correct output. Traversing the list of
inputs is possible but expensive. Typical work arounds such as `own_hash` in datum cannot be applied since the price
datum type is fixed.
