use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/assets
use cardano/transaction.{OutputReference, Transaction}
use latest_price_feed/tokens
use latest_price_feed/types as t
use sundae/multisig.{MultisigScript, satisfied}

validator placeholder(params: t.Params) {
  mint(_redeemer: Data, own_hash: ScriptHash, tx: Transaction) {
    trace @"mint.0 ": @"Own mint has precisely two entries."
    let Transaction { inputs, outputs, mint, .. } = tx
    trace @"mint.1 ": @"The names are precisely as in tokens."
    expect [Pair(n0, a0),
      Pair(n1, a1)] = mint |> assets.tokens(own_hash) |> dict.to_pairs
    expect n0 == tokens.aux
    expect n1 == tokens.price
    trace @"mint.2 ": @"The amounts are either both 1 or both -1."
    expect a0 == a1
    if a0 == 1 {
      trace @"mint.3 ": @"If amounts are 1, then"
      trace @"mint.3.0 ": @"Seed (params) is spend"
      expect inputs |> list.any(fn(i) { i.output_reference == params })
      trace @"mint.3.1 ": @"Find Price output with 0 datum."
      // let price_data = io.price_output(outputs.)
      trace @"mint.3.2 ": @"Find Aux output with 0 datum."
      todo
    } else {
      a0 == -1
    }
  }

  spend(
    datum: Option<t.Datum<Data>>,
    _redeemer: t.Redeemer,
    own_oref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction { validity_range, extra_signatories, withdrawals, .. } = tx
    //satisfied(datum, extra_signatories, validity_range, withdrawals)
    fail "Not yet implemented!"
  }

  else(_) {
    fail
  }
}
