use aiken/collection/list

// Like standard lib `at` but fails hard
pub fn at(xs: List<a>, i: Int) -> a {
  expect [x, ..xs] = xs
  if i == 0 {
    x
  } else {
    xs |> at(i - 1)
  }
}

// Pull two things from a list in a single traverse, with CPS
pub fn at2(xs: List<a>, i0: Int, i1: Int, return: fn(a, a) -> result) -> result {
  if i0 < i1 {
    do_at2(i1 - i0 - 1, i0, xs, return)
  } else {
    do_at2(i0 - i1 - 1, i1, xs, fn(a, b) { return(b, a) })
  }
}

// Use relative indicies
pub fn do_at2(
  i1: Int,
  idx0: Int,
  xs: List<a>,
  return: fn(a, a) -> result,
) -> result {
  expect [x, ..xs] = xs
  if idx0 == 0 {
    return(x, xs |> at(i1))
  } else {
    do_at2(i1, idx0 - 1, xs, return)
  }
}

// --- Tests ---

// -- At Tests --

test test_at_first() {
  let xs = [10, 20, 30]
  at(xs, 0) == 10
}

test test_at_first_base() {
  let xs = [10, 20, 30]
  expect Some(res) = list.at(xs, 0)
  res == 10
}

test test_at_middle() {
  let xs = [10, 20, 30]
  at(xs, 1) == 20
}

test test_at_middle_base() {
  let xs = [10, 20, 30]
  expect Some(res) = list.at(xs, 1)
  res == 20
}

test test_at_last() {
  let xs = [10, 20, 30]
  at(xs, 2) == 30
}

test test_at_last_base() {
  let xs = [10, 20, 30]
  expect Some(res) = list.at(xs, 2)
  res == 30
}

// -- At2 Tests --

test test_at2_ordered() {
  let xs = [10, 20, 30, 40, 50]
  at2(xs, 1, 3, fn(a, b) { a == 20 && b == 40 })
}

test test_at2_ordered_base() {
  let xs = [10, 20, 30, 40, 50]
  expect Some(a) = list.at(xs, 1)
  expect Some(b) = list.at(xs, 3)
  a == 20 && b == 40
}

test test_at2_reversed() {
  let xs = [10, 20, 30, 40, 50]
  at2(xs, 3, 1, fn(a, b) { a == 40 && b == 20 })
}

test test_at2_reversed_base() {
  let xs = [10, 20, 30, 40, 50]
  expect Some(a) = list.at(xs, 3)
  expect Some(b) = list.at(xs, 1)
  a == 40 && b == 20
}

test test_at2_adjacent() {
  let xs = [10, 20, 30]
  at2(xs, 0, 1, fn(a, b) { a == 10 && b == 20 })
}

test test_at2_adjacent_base() {
  let xs = [10, 20, 30]
  expect Some(a) = list.at(xs, 0)
  expect Some(b) = list.at(xs, 1)
  a == 10 && b == 20
}

test test_at2_distant() {
  let xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  at2(xs, 0, 9, fn(a, b) { a == 1 && b == 10 })
}

test test_at2_distant_base() {
  let xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  expect Some(a) = list.at(xs, 0)
  expect Some(b) = list.at(xs, 9)
  a == 1 && b == 10
}

pub fn at1_and(
  i: Int,
  f: fn(a, fn(b) -> result) -> result,
  list: List<a>,
  return: fn(b) -> result,
) -> result {
  expect [x, ..xs] = list
  if i == 0 {
    let bi <- f(x)
    return(bi)
  } else {
    at1_and(i - 1, f, xs, return)
  }
}

pub fn at2_and(
  i0: Int,
  f0: fn(a, fn(b0) -> result) -> result,
  i1: Int,
  f1: fn(a, fn(b1) -> result) -> result,
  list: List<a>,
  return: fn(b0, b1) -> result,
) -> result {
  expect [x, ..xs] = list
  if i0 == 0 {
    let b0 <- f0(x)
    at1_and(i1, f1, xs, fn(b1) { return(b0, b1) })
  } else {
    at2_and(i0 - 1, f0, i1, f1, xs, return)
  }
}

// Like at2_and but indicies are absolute
pub fn abs_at2_and(
  i0: Int,
  f0: fn(a, fn(b0) -> result) -> result,
  i1: Int,
  f1: fn(a, fn(b1) -> result) -> result,
  list: List<a>,
  return: fn(b0, b1) -> result,
) -> result {
  if i0 < i1 {
    // Relative index for i1 is i1 - i0 - 1
    at2_and(i0, f0, i1 - i0 - 1, f1, list, return)
  } else {
    // i1 is physically first in the list
    // Flip the order of extraction but preserve the return signature
    at2_and(i1, f1, i0 - i1 - 1, f0, list, fn(b1, b0) { return(b0, b1) })
  }
}

// --- Tests ---

test test_at1_and_index_zero() {
  let list = [10, 20, 30]
  let f =
    fn(a, cb) { cb(a * 2) }
  let return =
    fn(b) { b }
  at1_and(0, f, list, return) == 20
}

test test_at1_and_index_zero_base() {
  let items = [10, 20, 30]
  expect Some(item) = list.at(items, 0)
  let res = item * 2
  res == 20
}

// --- Middle Index ---

test test_at1_and_middle_index() {
  let list = [10, 20, 30, 40]
  let f =
    fn(a, cb) { cb(a + 5) }
  let return =
    fn(b) { b }
  at1_and(2, f, list, return) == 35
}

test test_at1_and_middle_index_base() {
  let items = [10, 20, 30, 40]
  expect Some(item) = list.at(items, 2)
  let res = item + 5
  res == 35
}

// --- Transformation ---

test test_at1_and_with_string_transformation() {
  let list = [1, 2, 3]
  let f =
    fn(a, cb) { cb(a > 1) }
  let return =
    fn(b) { b }
  at1_and(1, f, list, return) == True
}

test test_at1_and_with_string_transformation_base() {
  let items = [1, 2, 3]
  expect Some(item) = list.at(items, 1)
  let res = item > 1
  res == True
}

// --- Complex Return ---

test test_at1_and_complex_return() {
  let list = [100, 200, 300]
  let f =
    fn(a, cb) { cb(a / 2) }
  let return =
    fn(b) { b + 1 }
  at1_and(2, f, list, return) == 151
}

test test_at1_and_complex_return_base() {
  let items = [100, 200, 300]
  expect Some(item) = list.at(items, 2)
  let res = item / 2 + 1
  res == 151
}

// --- Start of List (Indices 0, 0) ---

test test_at2_and_start() {
  let items = [10, 20, 30]
  let f0 =
    fn(a, cb) { cb(a * 2) }
  let f1 =
    fn(a, cb) { cb(a + 5) }
  let return =
    fn(b0, b1) { b0 + b1 }

  // i0=0 -> 10. f0(10) -> 20.
  // Remaining list: [20, 30]. i1=0 -> 20. f1(20) -> 25.
  // Result: 20 + 25 = 45.
  at2_and(0, f0, 0, f1, items, return) == 45
}

test test_at2_and_start_base() {
  let items = [10, 20, 30]
  expect Some(item0) = list.at(items, 0)
  let b0 = item0 * 2
  // Logic: second element is at i0 + 1 + i1
  expect Some(item1) = list.at(items, 1)
  let b1 = item1 + 5
  b0 + b1 == 45
}

// --- Middle of List (Indices 1, 1) ---

test test_at2_and_middle() {
  let items = [1, 2, 3, 4, 5]
  let f0 =
    fn(a, cb) { cb(a) }
  let f1 =
    fn(a, cb) { cb(a) }
  let return =
    fn(b0, b1) { b0 + b1 }

  // i0=1 -> 2. b0=2.
  // xs starts after '2': [3, 4, 5]. i1=1 -> 4. b1=4.
  at2_and(1, f0, 1, f1, items, return) == 6
}

test test_at2_and_middle_base() {
  let items = [1, 2, 3, 4, 5]
  expect Some(item0) = list.at(items, 1)
  let b0 = item0
  // i0 (1) + 1 + i1 (1) = index 3
  expect Some(item1) = list.at(items, 3)
  let b1 = item1
  b0 + b1 == 6
}

// --- Different Types / Logic ---

test test_at2_and_logic() {
  let items = [10, 11, 12, 13]
  let f0 =
    fn(a, cb) { cb(a % 2 == 0) }
  let f1 =
    fn(a, cb) { cb(a % 2 != 0) }
  let return =
    fn(b0, b1) { b0 && b1 }

  // i0=0 -> 10 (even). b0=True.
  // i1=2 -> index 3 relative to original -> 13 (odd). b1=True.
  at2_and(0, f0, 2, f1, items, return) == True
}

test test_at2_and_logic_base() {
  let items = [10, 11, 12, 13]
  expect Some(item0) = list.at(items, 0)
  let b0 = item0 % 2 == 0
  expect Some(item1) = list.at(items, 3)
  let b1 = item1 % 2 != 0
  b0 && b1 == True
}

// --- Complex Structured Type Tests ---

type Asset {
  policy_id: ByteArray,
  quantity: Int,
  is_active: Bool,
}

test test_abs_at2_structured_types() {
  let asset1 = Asset { policy_id: "policy1", quantity: 100, is_active: True }
  let asset2 = Asset { policy_id: "policy2", quantity: 50, is_active: False }
  let asset3 = Asset { policy_id: "policy3", quantity: 10, is_active: True }
  let asset4 = Asset { policy_id: "policy4", quantity: 500, is_active: True }
  let assets = [asset1, asset2, asset3, asset4]

  // f0: gets quantity from index 3 (asset4)
  let f0 =
    fn(a: Asset, cb) { cb(a.quantity) }
  // f1: gets policy_id from index 1 (asset2)
  let f1 =
    fn(a: Asset, cb) { cb(a.policy_id) }

  let return =
    fn(qty, pid) { qty == 500 && pid == "policy2" }

  // Absolute indices: 3 and 1 (Flipped)
  abs_at2_and(3, f0, 1, f1, assets, return)
}

test test_abs_at2_structured_types_base() {
  let asset1 = Asset { policy_id: "policy1", quantity: 100, is_active: True }
  let asset2 = Asset { policy_id: "policy2", quantity: 50, is_active: False }
  let asset3 = Asset { policy_id: "policy3", quantity: 10, is_active: True }
  let asset4 = Asset { policy_id: "policy4", quantity: 500, is_active: True }
  let assets = [asset1, asset2, asset3, asset4]

  expect Some(item0) = list.at(assets, 3)
  let b0 = item0.quantity
  expect Some(item1) = list.at(assets, 1)
  let b1 = item1.policy_id
  b0 == 500 && b1 == "policy2"
}
