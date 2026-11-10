///|
fn decode_parts(
  basis : Bytes,
  delta : Bytes,
  chunk_size : Int32,
) -> Bytes raise {
  let decoder = @moonrdiff.PatchDecoder::new(
    basis_size=basis.length(),
    max_output=100000,
  )
  let output = @buffer.Buffer()
  let mut position = 0
  while position < delta.length() {
    let left = delta.length() - position
    let n = if chunk_size < left { chunk_size } else { left }
    for part in decoder.push(delta[position:position + n]) {
      match part {
        Literal(bytes) => output.write_bytes(bytes)
        Copy(offset~, length~) =>
          output.write_bytes(basis[offset:offset + length])
      }
    }
    position += n
  }
  decoder.finish()
  output.to_bytes()
}

///|
test "incremental patch matches whole decoder under all splits" {
  let basis = b"abcdefghijk"
  let payload = @buffer.Buffer()
  for i in 0..<1024 {
    payload.write_byte((i % 256).to_byte())
  }
  let delta = @moonrdiff.encode([
    Copy(offset=8, length=3),
    Literal(payload.to_bytes()),
    Copy(offset=0, length=8),
  ])
  for chunk_size in [1, 2, 3, 7, 16, 127, 128, 65536] {
    assert_eq(
      decode_parts(basis, delta, chunk_size),
      @moonrdiff.patch(basis, delta, max_output=100000),
    )
  }
  for length in 0..<delta.length() {
    assert_true(
      try {
        ignore(decode_parts(basis, delta[0:length].to_owned(), 7))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "incremental decoder rejects trailing bytes ranges overflow and budgets" {
  for
    delta in [
      b"bad magic", b"rs\x02\x36\x00x", b"rs\x02\x36\x55", b"rs\x02\x36\x45\xff\x01\x00",
      b"rs\x02\x36\x44\x80\x00\x00\x00\x00\x00\x00\x00",
    ] {
    assert_true(
      try {
        ignore(decode_parts(b"old", delta, 1))
        false
      } catch {
        _ => true
      },
    )
  }
  let decoder = @moonrdiff.PatchDecoder::new(basis_size=0, max_output=0)
  ignore(decoder.push(b"rs\x02\x36\x00"))
  decoder.finish()
  assert_true(
    try {
      ignore(decoder.push(b""))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      decoder.finish()
      false
    } catch {
      _ => true
    },
  )
  for (budget, instructions) in [(0, 1), (1, 0)] {
    let limited = @moonrdiff.PatchDecoder::new(
      basis_size=0,
      max_output=budget,
      max_instructions=instructions,
    )
    assert_true(
      try {
        ignore(limited.push(b"rs\x02\x36\x01x\x00"))
        false
      } catch {
        _ => true
      },
    )
    assert_true(
      try {
        limited.finish()
        false
      } catch {
        _ => true
      },
    )
  }
  let big = @moonrdiff.PatchDecoder::new(basis_size=0, max_output=0)
  assert_true(
    try {
      ignore(big.push(Bytes::make(65537, b'\x00')))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      big.finish()
      false
    } catch {
      _ => true
    },
  )
}

///|
test "incremental parser supports all parameter widths and short literals" {
  for a in 0..<4 {
    for b in 0..<4 {
      let bytes = @buffer.Buffer()
      bytes.write_bytes(b"rs\x02\x36")
      bytes.write_byte((69 + a * 4 + b).to_byte())
      for _ in 0..<((1 << a) - 1) {
        bytes.write_byte(b'\x00')
      }
      bytes.write_byte(b'\x01')
      for _ in 0..<((1 << b) - 1) {
        bytes.write_byte(b'\x00')
      }
      bytes.write_byte(b'\x02')
      bytes.write_byte(b'\x00')
      assert_eq(decode_parts(b"abcd", bytes.to_bytes(), 1), b"bc")
    }
    let bytes = @buffer.Buffer()
    bytes.write_bytes(b"rs\x02\x36")
    bytes.write_byte((65 + a).to_byte())
    for _ in 0..<((1 << a) - 1) {
      bytes.write_byte(b'\x00')
    }
    bytes.write_bytes(b"\x01z\x00")
    assert_eq(decode_parts(b"", bytes.to_bytes(), 1), b"z")
  }
  for length in 1..<=64 {
    let bytes = Bytes::make(length, b'x')
    assert_eq(decode_parts(b"", @moonrdiff.encode([Literal(bytes)]), 1), bytes)
  }
}
