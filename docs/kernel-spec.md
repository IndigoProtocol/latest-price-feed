# Kernel Spec :: Latest Price Feed

This document provides the specification of the kernel, ie "on-chain" component, of the Latest Price Feed application.

## Context

There are two existing protocols: Indigo and Orcfax. Orcfax is an oracle, publisher of data, while Indigo Protocol is
DeFi app, and a consumer of data. The objective is to have the data published by Orcfax consumable by Indigo Protocol.
The meaning and format of data Orcfax publishes does not match the format required as input for Indigo Protocol. The role of the Latest
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

Details of steps a validator must take to safely consume a fact statement are given in the documentation linked. These
include: finding a validity token in the value of the UTXO, verifying the feed ID, and deeming the created at value acceptable.

### Indigo

The Indigo Protocol expects a price feed to mean "latest price".
It consumes price feed data via the datum of a reference input. The reference input is identified by
the presence of an NFT (that can be set arbitrarily). The datum is of the following form

```aiken
Datum {
  price: OnChainDecimal,
  expire_at: Int,
}

OnChainDecimal {
  get_on_chain_int: 1_500_000 // = 1.500000
}
```

The `price` is expressed as an (albeit wrapped) int. The effective position of the decimal place is hard-coded in the
validator consuming the data.

## Requirements

Ultimate goal: Facilitate the consumption by Indigo Protocol of data derived from Orcfax Fact Statements.

Design assumptions:

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
1. On init, there is a specified `expiration_bias`, the time from a Fact statement's `created_at` and the resulting
   `expire_at`. That is, on each update `expire_at = created_at + expiration_bias`.
1. Sanity checks enforced on-chain:
   1. No non-zero output price
   1. No non-zero denominator of input

Non-requirements:

1. No restrictions on staking

## Design Overview

### Validators

The app consists of a single **seeded** validator, hereafter **main**, which can be executed in precisely mint and spend
purpose. By seeded, we mean that on init some UTXO specified in the validator parameters must be spent, and in doing we
guarantee uniqueness of the instance's validator (and so also script hash), provided the mint value consists of single
set of dapp NFTs.

Throughout "own" refers to belonging to the instances. For example: "own token" refers to a token with hash (aka
policy ID) of the instance; "own address" refers to an address with payment credentials corresponding to the instance
_etc_. In the present case, it is enforced that own address is unstaked.

### UTXOs

An instance, while running, has on-chain state of two UTXOs:

- Price - A reference input for the Indigo Protocol to consume price data.
- Aux - Facilitates the persistence of state on-chain required for the app to function.

Each UTXO can be identified by the presence of an NFT, both own tokens. At any point in time the UTXOs have the same
address, own address.

### Lifecycle

All instances are instantiated by the init. In an init the Price and Aux UTXOs are created. This involves minting the
NFTs.

An instance runs in a singular stage for its lifecycle. This stage is a fixed point under the two transactions.

1. Update: the Price and Aux are both spent together with Orcfax Fact Statement(s) as reference inputs.
1. Administer: the Aux is spent; the Price is not spent.

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

/// Datum Single
/// We don't need created at. Inferred from expire_at
type DatumSingle {
  Price { price : WrappedInt, expire_at : Timestamp }
  Aux { updater : VerificationKeyHash, admin : MultisigScript }
}

/// Datum multi
/// This definition is in part motivated to coax aiken to give us an ameanable cbor.
type DatumDouble {
  Price { price : WrappedInt, expire_at : Timestamp }
  Aux { created_ats : CreatedAts, updater : VerificationKeyHash, admin : MultisigScript }
}

CreatedAts {
    First(Timestamp)
    Second(Timestamp)
}

type WrappedInt {
  int : Int,
}

type MintRedeemer {
}
/// Redeemer.
type SpendRedeemer {
  Defer { own_in : Int, aux_in : Int }
  Update { own_in : Int, price_in : Int, price_out : Int }
  Administer
}
```

Note that by defining the type as above,
as CBOR `Price` serializes as though it is defined as:

```aiken
type PriceDatum {
  price : WrappedInt
  expire_at : Int,
}
```


#### Env

We have several types of 
TODO.

At present there is no declaration of feed ID(s), or Price Align.
Doing this at the env level is sufficiently convenient.

#### Logic

##### IO

Transactions are constrained in part by the conditions of own inputs and outputs. 
We specify the logic for own inputs and outputs here.

In all txs, the redeemer indicates the indices of the relevant inputs and outputs.

###### Inputs

There are several cases why inspecting inputs is requied: 

- determining own hash
- the inclusion or non inclusion of the "other" input
- extracting the data from the other input

A transaction may do none, one, or more of these.
By the quirks of Cardano, we have own datum from the execution context directly, 
and so never need to recover more than one.

An input, Aux or Price, is entirely verified by its validity token. 
The global behvaiour ensures that a validity token is an NFT, and that it is locked at own address. 
So to get input datum from own hash: 

- gid.0 : Pull value and datum
- gid.1 : Value contains correct NFT
- gid.2 : Expect datum is inlined datum and return

However, to recognize own token we require knowing `own_hash`. 
The spend purpose provides to the execution context the output reference. 
We must use this to establish `own_hash`.
Get own hash from output reference:  

- goh.0 : Output reference matches target
- goh.1 : Extract script hash from address payment credential
- goh.2 : Value contains correct NFT
- goh.3 : Return own hash

There are transactions in which both Price and Aux must be present, or 
the "other" input must _not_ be present. 

In the case of both, we combine the two above.
That is, from own get other:

- fogo.0 : Get own input and other input from inputs 
- fogo.1 : Get own hash from own input
- fogo.2 : Get other datum 

In cases where inclusion of "other" is required, but the data is not, we could speicialize the logic.
For now we will just ignore the retreived data.

###### Outputs

The context of handling outputs is more uniform that inputs:

- `own_hash` is always available.
- We always need to retrieve the data.

The two cases are whether we require a single continuing output, or both. 
In either case, the verification for an output is stricter than an input. 
We retreive the datum for additional validation steps.

Get output data:

- god.0 : Address is own address
- god.1 : Value is Ada and correct NFT.
- god.2 : Script ref is none.
- god.3 : Datum is inlined data. Return data

##### Mint Purpose

The constraints enforce that a transaction involving own is either the init, or the burn of an instance. As the script
is seeded, the init is unique. As the init is unique so to is the burn.

Mint Redeemer is `{price_out, aux_out}`

- mint.0 : Own mint has precisely two entries.
- mint.1 : The names are precisely as in tokens.
- mint.2 : The amounts are both 1.
- mint.3 : Seed (params) is spend
- mint.4 : Price output with "zero" datum.
- mint.5 : Aux output with "zero" datum.

At init, the datums are set to their "zero value". The Price datum zero is `Price(WrappedInt(0), 0)`. The Aux datum zero
will have `created_ats` set to `0` as applicable.

##### Spend Purpose

If datum, spend redeemer are `(Price, Defer{own_in, aux_in}`,

- defer.0 : `own_in`th input is own input. Derive own hash.
- defer.0 : `aux_in`th input is Aux input

If datum, spend redeemer are `(Aux, Update{own_in, price_in, price_out})`

- update.0 : `own_in`th input is own input. Derive own hash.
- update.1 : `price_in`th input is Price. 
- update.2 : `price_out`th output is Price. 
- update.3 : `price_out + 1`th output is Aux. 
- update.4 : Recover orcfax reference inputs
- update.5 : Price out aligns with referenced Fact Statement(s)
- update.6 : Update is newer

If datum, spend redeemer are `(Aux, Administer)`

- admin.0 : `admin` (Aicone) is satisfied.
- admin.1 : Either
  - admin.1.0 : Continuing output has only modified `updater` and `admin`
  - admin.1.1 : No `Price` token is output
- admin.2 : Or own mint is non-empty

All other datum, redeemer pairs fail.

All constraints imposed on the spend of Price are deferred to execution of Aux. In these cases, the validator verifies
that the transaction also spends Aux.
As a consequence, Aux must always verify the outcome of Price, including verifying its non-inclusion where appropriate.

The `Administer` redeemer is used to spend in a burn transaction.

#### Functions

##### Value Representation

The expression of price in Orcfax is different to that of Indigo Protocol. 
We should not expect equality, but instead bound the divergence between the two. 

- Orcfax representation of value is of the form `(num, denom)` (numerator, denominator). 
- Indigo Protocol representation of value is of the form `(sig, exp)` (significand, exponent). 

We can easily convert this to rational representation `(sig, 10 ^(-exp))`.

##### Alignment 

We say two (non-zero) numbers $a$ and $b$ are **$\delta$-aligned** if 

$$
1 - \delta \geq \frac{a}{b} \geq 1 + \delta
$$

Strictly speaking this is not a symmetric relation in $a$ and $b$, 
although it is upto symmetic upto first order in $\delta$. 
That is, the above implies

$$
1 - \delta + o(\delta) \geq \frac{b}{a} \geq 1 + \delta + o(\delta) 
$$

In a validator we can only handle integers.
We introduce precision $p$ and threshold $\epsilon$ for the role of $\delta$.
Let $a = \frac{a_n}{a_d}$, and $b = \frac{b_n}{b_d}$, then

$$
\frac{p - \epsilon}{p} \geq \frac{a_d * b_d}{a_d * b_n} \geq \frac{p + \epsilon}{p}
$$

Flattening this, and encoding as an aiken function results in the following: 

```aiken
pub fn is_aligned(a_n : Int, a_d : Int, b_n: Int, b_d: Int, epsilon: Int, precision: Int) {
  let x = a_n * b_d * precision
  let y = a_d * b_n
  let lb = (precision - epsilon) * y
  let ub = (precision + epsilon) * y
  lb <= x && x <= ub
}
```

#### Specialization

The `exp` is fixed in the Indigo consumer of the data. 
In particular it is fixed at compile time of LPF main validator.
We assume that it is non-positive.
We may also fix the desired precision and epsilon at compile time. 

We can specialize our `is_aligned` function to both simplify and optimize logic.

```aiken
// ./env/example.ak
pub const exp : Int = ...
pub const epsilon : Int = ... 
pub const precision : Int = ... 
```

Then: 

```aiken
use env

const scale : Int = math.pow(10, -env.exp) 
const lb = env.precision - env.epsilon
const ub = env.precision + env.epsilon

pub fn is_aligned(num : Int, denom : Int, sig: Int,) {
  let x = num * scale * precision
  let y = denom * sig
  lb * y <= x && x <= ub * y
}
```

#### Conversion 

Let's say that an Indigo value represents the price pair A-B. 
Orcfax may have a data feed representing the same price pair A-B.
However, it may require additional computation steps.
We support the possibility that Orcfax provides feeds: 

- A-B
- B-A
- A-C, C-B
- C-A, C-B
- A-C. B-C
- C-A, B-C

We lean into this for naming.






The exponent may be positive and negative.
Let `scale = pow(10, exp)` and if `n < 0` then `neg_scale = pow(10, -exp)`. 

```aiken
fn verify_ab( num : Int, denom : Int, sig : Int ) {
    let diff  = num * scale - sig * denom
    - threshold < diff && diff < threshold
}

fn verify_ab_neg( num : Int, denom : Int, sig : Int ) {
    let diff  = num - sig * denom * neg_scale
    - threshold < diff && diff < threshold
}
```


For a reciprocal

```aiken
fn verify_ba( num : Int, denom : Int, sig : Int ) {
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

In an update the continuing price must be newer. In a one Fact Statement case, it is sufficient to verify that

```aiken
expect cont_datum.expirte_at == created_at + expiration_bias
expect cont_datum.expire_at > prev_datum.expire_at
```

In the case of product, where there are two Fact Statements, then there is a decision as to what the `cont_datum.expire_at` should be.
The other Fact Statement's `created_at` is recorded in the aux datum. On an update, at least one must be later.

Warning: It is possible to do something a little odd in this case.
The current design would permit an update that isn't the desireable behaviour.
Suppose we have a LPF that depends on feeds A and B. Suppose the prev datum and its update datum that are calculated from Fact Statements at
times `(a0, b0)` and `(a1, b1)` respectively.
Its possible that `a0 < b1 < b0 < a1`.

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
