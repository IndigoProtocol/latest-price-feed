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
/// This definition is in part motivated to coax aiken to give us an ameanable cbor.
pub type DatumSingle {
  Price { price: WrappedInt, expire_at: Timestamp }
  Aux { updater: VerificationKeyHash, admin: MultisigScript }
}

pub const price_zero = Price(WrappedInt(0), 0)

pub type WrappedInt {
  int: Int,
}

pub type SpendRedeemer {
  Defer { own_in: Int, aux_in: Int }
  Update { own_in: Int, price_in: Int, price_out: Int }
  Administer
}

pub type MintRedeemer {
  aux_out: Int,
  price_out: Int,
}
