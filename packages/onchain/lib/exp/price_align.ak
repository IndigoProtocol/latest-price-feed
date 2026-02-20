use aiken/collection/list
use aiken/math

pub fn is_aligned(
  sig: Int,
  exp: Int,
  num: Int,
  denom: Int,
  epsilon: Int,
  precision: Int,
) {
  expect exp <= 0
  let scale = math.pow(10, -exp)
  let x = num * scale * precision
  let y = sig * denom
  let lb = ( precision - epsilon ) * y
  let ub = ( precision + epsilon ) * y
  lb <= x && x <= ub
}

const simple_test_vec =
  [
    // 3000. Exact
    ((3000, 0, 3000, 1, 0, 1), True),
    // A half
    ((15, -1, 3, 2, 0, 1), True),
    // 0.155, Approximate. Borderline theshold.
    ((155, -2, 3, 2, 1, 31), True),
    // 0.155, Approximate. Exceed theshold.
    ((155, -2, 3, 2, 1, 100), False),
    // // 0.155, Approximate. Beneath theshold.
    ((155, -2, 3, 2, 4, 100), True),
  ]

test test_is_aligned_simple() {
  simple_test_vec
    |> list.all(
        fn(tup) {
          let ((exp, sig, num, denom, t_n, t_d), want) = tup
          let got = is_aligned(exp, sig, num, denom, t_n, t_d)
          want == got
        },
      )
}

// Approximations of pi
const pi_test_vec =
  [
    // Error + 0.0012 
    ((22, 7, 5, 10000), True),
    ((22, 7, 4, 10000), False),
    // Accurate to 4 dp
    ((333, 106, 5, 10000), True),
    // Accurate to 6 dp
    ((355, 113, 5, 1000000), True),
    // // Accurate to 9 dp
    ((103993, 33102, 1, math.pow(10, 9)), True),
    ((103993, 33102, 1, math.pow(10, 11)), False),
  ]

test test_is_aligned_pi() {
  let (exp, sig) = (-12, 3141592653589)
  pi_test_vec
    |> list.all(
        fn(tup) {
          let ((num, denom, t_n, t_d), want) = tup
          let got = is_aligned(sig, exp, num, denom, t_n, t_d)
          want == got
        },
      )
}

pub type Fraction {
  n: Int,
  d: Int,
}

pub fn approximate(sig: Int, exp: Int, max_denom: Int) -> Fraction {
  let target_n =
    if exp >= 0 {
      sig * math.pow(10, exp)
    } else {
      sig
    }
  let target_d =
    if exp < 0 {
      math.pow(10, -exp)
    } else {
      1
    }
  // Starting bounds: 0/1 and 1/0 (represented as 1/0)
  find_fast(target_n, target_d, max_denom, 0, 1, 1, 0)
}

fn find_fast(
  tn: Int,
  td: Int,
  max_d: Int,
  ln: Int,
  ld: Int,
  rn: Int,
  rd: Int,
) -> Fraction {
  let mn = ln + rn
  let md = ld + rd

  if md > max_d {
    if ( tn * ld - td * ln ) * rd < ( rn * td - rd * tn ) * ld {
      Fraction { n: ln, d: ld }
    } else {
      Fraction { n: rn, d: rd }
    }
  } else {
    let left_side = tn * md
    let right_side = mn * td

    if left_side == right_side {
      Fraction { n: mn, d: md }
    } else if left_side > right_side {
      // We need to move RIGHT. 
      // How many times can we move right before we overshoot or hit max_d?
      // Calculation: k = (tn*ld - td*ln) / (td*rn - tn*rd)
      let num_diff = tn * ld - td * ln
      let den_diff = td * rn - tn * rd
      let k =
        if den_diff == 0 {
          1
        } else {
          num_diff / den_diff
        }
      let k_constrained =
        math.min(
          k,
          if rd == 0 {
            max_d
          } else {
            ( max_d - ld ) / rd
          },
        )
      let k_final = math.max(1, k_constrained)

      let next_ln = ln + k_final * rn
      let next_ld = ld + k_final * rd
      find_fast(tn, td, max_d, next_ln, next_ld, rn, rd)
    } else {
      // We need to move LEFT.
      // How many times can we move left before we overshoot or hit max_d?
      // Calculation: k = (td*rn - tn*rd) / (tn*ld - td*ln)
      let num_diff = td * rn - tn * rd
      let den_diff = tn * ld - td * ln
      let k =
        if den_diff == 0 {
          1
        } else {
          num_diff / den_diff
        }
      let k_constrained =
        math.min(
          k,
          if ld == 0 {
            max_d
          } else {
            ( max_d - rd ) / ld
          },
        )
      let k_final = math.max(1, k_constrained)

      let next_rn = rn + k_final * ln
      let next_rd = rd + k_final * ld
      find_fast(tn, td, max_d, ln, ld, next_rn, next_rd)
    }
  }
}

test test_approx_half() {
  let res = approximate(5, -1, 10)
  (res.n, res.d) == (1, 2)
}

test test_approx_third() {
  let res = approximate(33333, -5, 10)
  (res.n, res.d) == (1, 3)
}

test test_approx_pi() {
  let res = approximate(314159, -5, 105)
  (res.n, res.d) == (311, 99)
}

const ada_btc_test_vec =
  [
    // Ada bitcoin : "0.00000394"
    ((394, -8, 28, 7106599, 1, 1000), True),
    ((394, -8, 28, 7106599, 1, 1000), True),
  ]

test test_ada_btc() {
  ada_btc_test_vec
    |> list.all(
        fn(tup) {
          let ((sig, exp, num, denom, t_n, t_d), want) = tup
          let got = is_aligned(sig, exp, num, denom, t_n, t_d)
          want == got
        },
      )
}

// Choosen as a test case for large decimal representation
const shib_btc_vec =
  [
    // Target: 0.000000000091041732 (91041732 * 10^-18)
    // Test 1: 1/1 should be False (it's nowhere near)
    ((91041732, -18, 1, 1, 1, 10), False),
    // Test 2: An actual approximation should be True
    // Some sanity checks that we've understood precision.
    ((91041732, -18, 1, 10983979400, 6, 10000000), True),
    ((91041732, -18, 1, 10983979400, 5, 10000000), False),
    ((91041732, -18, 1, 10983979400, 60, 100000000), True),
    ((91041732, -18, 1, 10983979400, 50, 100000000), False),
    ((91041732, -18, 1, 10983979400, 509, 1000000000), True),
    ((91041732, -18, 1, 10983979400, 508, 1000000000), False),
  ]

test test_shib_btc() {
  shib_btc_vec
    |> list.all(
        fn(tup) {
          let ((sig, exp, num, denom, t_n, t_d), want) = tup
          let got = is_aligned(sig, exp, num, denom, t_n, t_d)
          want == got
        },
      )
}
