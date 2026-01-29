use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference}
use sundae/multisig.{MultisigScript}

/// Posix time in milliseconds, as it appears in validity range for example.
pub type Timestamp =
  Int

/// Seed
pub type Params =
  OutputReference

/// Datum
/// This definition is in part motivated to coax aiken
/// to give us an ameanable cbor.
/// The `Aux` fields are referred to as `(created_ats, updater, admin)`
pub type Datum<t> {
  Price(WrappedInt, Timestamp)
  Aux(t, VerificationKeyHash, MultisigScript)
}

pub type WrappedInt {
  int: Int,
}

/// Note that by defining the type as above,
/// as CBOR `Price` serializes as though it is defined as:
pub type PriceDatum {
  price: WrappedInt,
  expire_at: Int,
}

/// Redeemer.
/// Defer(own_index, aux_index)
/// Update(own_index, price_in, price_out)
pub type Redeemer {
  Defer(Int, Int)
  Update(Int, Int, Int)
  Administer
}
