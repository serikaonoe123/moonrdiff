///|
test "signature is independent of input partition including empty pushes" {
  for length in [0, 1, 31, 32, 33, 127, 128, 129, 255, 256, 257, 4097] {
    let input = @buffer.Buffer()
    for i in 0..<length {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for block_size in [1, 32, 128, 2048] {
      for chunk_size in [1, 7, 128, 65536] {
        let encoder = @moonrdiff.SignatureEncoder::new(block_size~)
        let output = @buffer.Buffer()
        output.write_bytes(encoder.push(b""))
        let mut position = 0
        while position < length {
          let remaining = length - position
          let n = if chunk_size < remaining { chunk_size } else { remaining }
          output.write_bytes(encoder.push(bytes[position:position + n]))
          assert_true(encoder.buffered_bytes() < block_size)
          position += n
        }
        output.write_bytes(encoder.finish())
        assert_eq(output.to_bytes(), @moonrdiff.signature(bytes, block_size~))
        assert_eq(encoder.output_bytes(), output.to_bytes().length())
      }
    }
  }
}

///|
test "stream lifecycle and budgets fail closed" {
  let encoder = @moonrdiff.SignatureEncoder::new()
  assert_eq(encoder.finish(), @moonrdiff.signature(b""))
  assert_true(
    try {
      ignore(encoder.finish())
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(encoder.push(b"x"))
      false
    } catch {
      _ => true
    },
  )
  let limited = @moonrdiff.SignatureEncoder::new(block_size=1, max_blocks=1)
  assert_true(
    try {
      ignore(limited.push(b"ab"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(limited.push(b""))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(limited.finish())
      false
    } catch {
      _ => true
    },
  )
  let tail = @moonrdiff.SignatureEncoder::new(block_size=32, max_output=12)
  ignore(tail.push(b"x"))
  assert_true(
    try {
      ignore(tail.finish())
      false
    } catch {
      _ => true
    },
  )
  let huge = @moonrdiff.SignatureEncoder::new()
  assert_true(
    try {
      ignore(huge.push(Bytes::make(65537, b'\x00')))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(huge.finish())
      false
    } catch {
      _ => true
    },
  )
  for
    (block_size, strong_length, max_blocks, max_output) in [
      (0, 32, 1, 12),
      (1048577, 32, 1, 12),
      (1, 0, 1, 12),
      (1, 33, 1, 12),
      (1, 32, -1, 12),
      (1, 32, 1, 11),
    ] {
    assert_true(
      try {
        ignore(
          @moonrdiff.SignatureEncoder::new(
            block_size~,
            strong_length~,
            max_blocks~,
            max_output~,
          ),
        )
        false
      } catch {
        _ => true
      },
    )
  }
}
