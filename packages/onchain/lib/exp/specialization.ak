use aiken/math

/// Example of using specialization
const exp: Int = 5

const epsilon: Int = 1

const precision: Int = 1000

const scale: Int = math.pow(10, -exp)

const lb = precision - epsilon

const ub = precision + epsilon

pub fn is_aligned(num: Int, denom: Int, sig: Int) {
  let x = num * scale * precision
  let y = denom * sig
  lb * y <= x && x <= ub * y
}
