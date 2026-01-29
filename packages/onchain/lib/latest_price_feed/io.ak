use aiken/crypto.{ScriptHash, VerificationKeyHash}
use cardano/address.{Address}
use cardano/assets
use cardano/transaction.{InlineDatum, Input, Output}
use latest_price_feed/tokens
use latest_price_feed/types.{Aux, Datum, Price}
use sundae/multisig.{MultisigScript}

pub fn aux_input(own_hash: ScriptHash, input: Input) -> Bool {
  trace @"ai.0": @"Value contains aux NFT."
  ( input.output.value |> assets.quantity_of(own_hash, tokens.aux) ) == 1
}

pub fn price_output(
  own_hash: ScriptHash,
  own_address: Address,
  output: Output,
) -> (Int, Int) {
  let Output { address, value, datum, reference_script } = output
  trace @"po.0": @"Address is own address"
  expect address == own_address
  trace @"po.1": @"Value is Ada and price NFT."
  expect
    value
      |> assets.match(
          [Pair(own_hash, [Pair(tokens.price, 1)])],
          fn(_, _) { True },
        )
  trace @"po.2": @"Datum is inlined `Price`"
  expect InlineDatum(datum) = datum
  expect Price(wrapped, created_at): Datum<Data> = datum
  trace @"po.3": @"Script ref is none."
  expect reference_script == None
  (wrapped.int, created_at)
}

pub fn aux_output(
  own_hash: ScriptHash,
  own_address: Address,
  output: Output,
) -> (Data, VerificationKeyHash, MultisigScript) {
  let Output { address, value, datum, reference_script } = output
  trace @"ao.0": @"Address is own address"
  expect address == own_address
  trace @"ao.1": @"Value is Ada and aux NFT."
  expect
    value
      |> assets.match(
          [Pair(own_hash, [Pair(tokens.aux, 1)])],
          fn(_, _) { True },
        )
  trace @"ao.2": @"Datum is inlined `Aux`"
  expect InlineDatum(datum) = datum
  expect Aux(data, updater, multisig): Datum<Data> = datum
  trace @"ao.3": @"Script ref is none."
  expect reference_script == None
  (data, updater, multisig)
}
