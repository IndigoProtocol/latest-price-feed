# Alternative design proposal

> STATUS :: THIS STUB WILL NOT BE PERSUED FURTHER

## Problem

The existing design consists of single validator, main, evaluated with mint or spend purpose. The reasons for the design
and need to couple UTXOs sharing an address is described in the other document.

## Solution

There are multiple parts of the logic that can be skipped if we have two separate validators.

### Overview

There are two validators:

- Aux - Seeded validator. Maintains the aux data
- Price - Parameterized by Aux validator. Maintains the price data in the format required by Indigo Protocol.

### Data.

```aiken
type AuxParams = OutputReference

type AuxDatum {
    hashes : (own_hash, price_hash),
    created_ats: Int,
    updater : Hash<28>,
    admin : MutlisigScript,
}

/// The param is the hash of the aux script
type PriceParams = Hash<28>

/// Price datum is unchanged
type PriceDatum {
 ...
}

type PriceRedeemer = Index

```

#### Logic

Price finds Aux input:

- Aux NFT in `index` input. Else try next input.

Aux does not need to find price input

...
