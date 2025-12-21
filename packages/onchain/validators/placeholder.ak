use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction, OutputReference}

use sundae/multisig.{MultisigScript, satisfied}

validator placeholder {
  mint(_redeemer: Data, _policy_id: PolicyId, _self: Transaction) {
    todo @"mint logic goes here"
  }

  spend(datum: Option<MultisigScript>, _redeemer: Data, _utxo: OutputReference, tx: Transaction) {
    expect Some(datum) = datum
    let Transaction { validity_range, extra_signatories, withdrawals, .. }  = tx
    satisfied(datum, extra_signatories, validity_range, withdrawals )
  }

}
