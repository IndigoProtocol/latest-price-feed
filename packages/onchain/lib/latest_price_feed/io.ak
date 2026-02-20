use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use latest_price_feed/tokens
use x/xlist

pub fn get_own_hash(
  name: ByteArray,
  oref: OutputReference,
  input: Input,
) -> ScriptHash {
  let Input { output_reference, output } = input
  trace @"goh.0": @"Output reference matches target"
  expect oref == output_reference
  let Output { address, value, .. } = output
  trace @"goh.1": @"Extract script hash from address payment credential"
  expect Script(own_hash) = address.payment_credential
  trace @"goh.2": @"Value contains correct NFT"
  expect assets.quantity_of(value, own_hash, name) == 1
  trace @"goh.3": @"Return own hash"
  own_hash
}

pub fn get_input_data(
  name: ByteArray,
  own_hash: ScriptHash,
  input: Input,
) -> Data {
  trace @"gid.0": @"Pull value and datum"
  let Output { value, datum, .. } = input.output
  trace @"gid.1": @"Value contains correct NFT"
  expect assets.quantity_of(value, own_hash, name) == 1
  trace @"gid.2": @"Expect datum is inlined datum and return"
  expect InlineDatum(datum) = datum
  datum
}

pub fn from_own_get_other(
  own_name: ByteArray,
  other_name: ByteArray,
  own_oref: OutputReference,
  own_in: Int,
  other_in: Int,
  inputs: List<Input>,
) -> Data {
  trace @"fogo.0": @"Get own input and other input from inputs "
  let own_input, other_input <-
    xlist.at2(inputs, own_in, other_in, _)
  trace @"fogo.1": @"Get own hash from own input"
  let own_hash = get_own_hash(own_name, own_oref, own_input)
  trace @"fogo.2": @"Get other datum "
  get_input_data(other_name, own_hash, other_input)
}

pub fn aux_get_price(
  own_oref: OutputReference,
  own_in: Int,
  price_in: Int,
  inputs: List<Input>,
) -> Data {
  from_own_get_other(
    tokens.aux,
    tokens.price,
    own_oref,
    own_in,
    price_in,
    inputs,
  )
}

pub fn price_get_aux(
  own_oref: OutputReference,
  own_in: Int,
  price_in: Int,
  inputs: List<Input>,
) -> Data {
  from_own_get_other(
    tokens.price,
    tokens.aux,
    own_oref,
    own_in,
    price_in,
    inputs,
  )
}

pub type FnDataData<result> =
  fn(Data, Data) -> result

pub fn get_output_data(
  name: ByteArray,
  own_hash: ScriptHash,
  output: Output,
) -> Data {
  let Output { address, value, datum, reference_script } = output
  trace @"god.0" : @"Address is own address"
  expect Address(Script(own_hash), None) == address
  trace @"god.1" : @"Value is Ada and correct NFT."
  expect
    value
      |> assets.match([Pair(own_hash, [Pair(name, 1)])], fn(_, _) { True })
  trace @"god.2" : @"Script ref is none."
  expect reference_script == None
  trace @"god.3" : @"Datum is inlined data. Return data"
  expect InlineDatum(datum) = datum
  datum
}

pub fn own_outputs_data(
  own_hash: ScriptHash,
  aux_out: Int,
  price_out: Int,
  outputs: List<Output>,
  return: FnDataData<result>,
) -> result {
  let aux_output, price_output <-
    xlist.at2(outputs, aux_out, price_out, _)
  let aux_data = get_output_data(tokens.aux, own_hash, aux_output)
  let price_data = get_output_data(tokens.price, own_hash, price_output)
  return(aux_data, price_data)
}
