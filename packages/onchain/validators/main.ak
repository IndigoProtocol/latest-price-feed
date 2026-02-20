use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/assets
use cardano/transaction.{OutputReference, Transaction}
use latest_price_feed/io
use latest_price_feed/tokens
use latest_price_feed/types as t
use sundae/multisig.{MultisigScript, satisfied}

validator main(params: t.Params) {
  mint(_redeemer: t.MintRedeemer, own_hash: ScriptHash, tx: Transaction) {
    let Transaction { inputs, outputs, mint, .. } = tx
    trace @"mint.0 ": @"Own mint has precisely two entries."
    trace @"mint.1 ": @"The names are precisely as in tokens."
    trace @"mint.2 ": @"The amounts are both 1"
    expect dict.to_pairs(assets.tokens(mint, own_hash)) == tokens.mint

    trace @"mint.3.0 ": @"Seed (params) is spend"
    expect inputs |> list.any(fn(i) { i.output_reference == params })
    trace @"mint.4": @"Find Price output with zero datum."

    trace @"mint.5": @"Find Aux output."
    fail @"NOT YET COMPLETE"
  }

  spend(
    datum: Option<t.DatumSingle>,
    _redeemer: t.SpendRedeemer,
    own_oref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction { validity_range, extra_signatories, withdrawals, .. } = tx
    //satisfied(datum, extra_signatories, validity_range, withdrawals)
    fail @"Not yet implemented!"
  }

  else(_) {
    fail
  }
}
