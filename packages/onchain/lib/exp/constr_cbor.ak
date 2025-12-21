


type Single {
  s0: Int, 
  s2: ByteArray,
}

type Double {
  A(Int, ByteArray)
  B(Int, ByteArray)
}

test test_cbor() {
  let single : Data = Single(3, "hello") 
  let a : Data = A(3, "hello") 
  let b : Data = B(3, "hello") 

  expect single == a 
  expect single != b 
}
