use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/assets.{Value}
use cardano/transaction.{InlineDatum, Input, Output}
use env
use orcfax/rational.{Rational}
use orcfax/tokens.{fsp_vali}
use orcfax/types.{FsDat, Statement}

pub fn has_fs_token(fs_hash: ScriptHash, value: Value) {
  assets.quantity_of(value, fs_hash, fsp_vali()) == 1
}

type Return<result> =
  fn(Statement<Rational>) -> result
// /// We assume and verify that the input is a valid FS UTXO
// pub fn extact_rational_statement(
//   input: Input,
//   return: Return<result>,
// ) {
//   let Output { datum, value, .. } = input.output
//   expect has_fs_token(value)
//   expect InlineDatum(datum) = datum 
//   expect datum : FsDat<Rational> = datum
//   return(datum.statement)
// }
