///|
/// Golden bytes generated independently with Python hashlib BLAKE2b-256.
test "signature golden tail block and truncated strong hash" {
  let actual = @moonrdiff.signature(b"abcde", block_size=4, strong_length=16)
  assert_eq(
    actual, b"\x72\x73\x01\x47\x00\x00\x00\x04\x00\x00\x00\x10\x23\x8b\xd8\x73\x9c\xc3\x91\x2a\x04\x28\x27\xe4\x59\x83\xed\x53\xdf\x3c\x75\x9f\x08\x10\x42\x8a\x8d\x23\x43\x02\xae\xb0\x6f\x2a\x7e\xff\xb9\x05\xe4\x3f\x03\x7e",
  )
  let parsed = @moonrdiff.parse_signature(actual)
  assert_eq(parsed.block_count(), 2)
  assert_eq(parsed.to_bytes(), actual)
}

///|
test "empty basis and budgets" {
  let empty = @moonrdiff.signature(b"", block_size=32, max_blocks=0)
  assert_eq(@moonrdiff.parse_signature(empty, max_blocks=0).block_count(), 0)
  for
    (block_size, strong_length, max_blocks) in [
      (0, 32, 1),
      (-1, 32, 1),
      (1, 0, 1),
      (1, 33, 1),
      (1, 32, -1),
      (1, 32, 2),
    ] {
    let rejected = try {
      ignore(
        @moonrdiff.signature(b"abc", block_size~, strong_length~, max_blocks~),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "signature parser truncation header and block budget" {
  let valid = @moonrdiff.signature(b"abcde", block_size=4, strong_length=16)
  for length in 0..<valid.length() {
    // Complete prefix signatures are valid: the format has no record count.
    if length == 12 || length == 32 {
      continue
    }
    let rejected = try {
      ignore(@moonrdiff.parse_signature(valid[0:length].to_owned()))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(@moonrdiff.parse_signature(valid, max_blocks=1))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  for
    header in [
      b"rs\x01G\x00\x00\x00\x00\x00\x00\x00\x20", b"rs\x01G\x00\x00\x00\x01\x00\x00\x00\x21",
      b"rs\x01G\x80\x00\x00\x00\x00\x00\x00\x20",
    ] {
    let rejected = try {
      ignore(@moonrdiff.parse_signature(header))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
/// Regression: exact and neighbouring BLAKE2 block boundaries.
test "BLAKE2 full block finalization regression" {
  {
    let input = @buffer.Buffer()
    for i in 0..<0 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<1 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x08\x10\x43\x24\xac\x4e\x40\x76\xa8\x83\x93\x72\x82\xf1\x37\x7e\xf5\xca\xcb\x8e\xdd\x00\xe3\xc7\x96\x29\xe4\x35\x32\x46\x4e\xb3\xbe\x27\x73\x67",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<127 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\xf1\x07\x69\x6f\xe8\x32\x33\xa7\x2f\x93\xb5\x2d\x1e\x75\x47\x5d\xf3\xee\xad\xf1\x76\x23\x0c\x09\x0a\x6d\x20\xa8\x3b\xd8\x78\x02\x49\x6e\x32\xe2",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<128 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\xce\x30\xdb\x41\xb0\x07\xed\x92\xd5\x85\x55\x4b\x8d\xab\x53\x01\xcd\x34\xf8\x60\x66\x89\x87\x38\x39\xe4\x16\x7c\x5b\xfb\xe1\x8b\x1d\x3f\x73\xf1",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<129 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x21\xa6\x72\xe4\x61\x25\xaf\xec\x0a\xff\xd5\xaa\xcf\xfe\x40\xe5\x6a\x1f\x0c\x3e\x15\x16\x33\x76\xe8\x75\xc1\x3a\x61\x4f\x6c\x2a\x47\xbc\x8c\x0a",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<255 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x93\x3c\x2c\x2f\xa7\x01\xc7\x35\xaf\x43\xe3\x55\xef\xe1\x5e\x49\x18\xae\x98\xd6\xd9\xb7\xd5\x76\x69\x48\x62\x0f\x11\x6a\x3b\x99\x11\x54\xe1\xf2",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<256 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x06\x06\x81\x81\xb7\x9a\xe2\x82\x9b\x3a\xd9\xe8\xf4\x91\xc8\x0f\x30\xd3\x57\xb1\x16\xce\x97\xc7\xdd\xf6\xf1\x1b\xbe\x18\xb1\xb5\x1b\x7e\x49\xc1",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<257 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\xac\x63\xfa\xa4\xf5\xc4\x84\xdb\xcc\x57\xca\x7a\x63\xf3\xd7\xe0\xf8\x3c\x66\x69\xfe\x2b\x52\x80\x74\x7a\x6e\x3d\x0a\xad\x9c\xe1\xd2\xf6\xdf\x8d",
    )
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<384 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(
      @moonrdiff.signature(input.to_bytes(), block_size=1024),
      b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x68\x4c\x5c\xc1\x10\x3b\x68\x9e\xef\xe7\xe4\x5a\xd8\x01\xad\x1a\x22\x68\xa3\x30\x82\x73\x0e\x95\x2e\xc1\x25\xbb\x15\x94\xc0\x42\x03\xb3\x02\xf5",
    )
  }
  let input = @buffer.Buffer()
  for i in 0..<512 {
    input.write_byte(((i * 73 + 255) % 256).to_byte())
  }
  assert_eq(
    @moonrdiff.signature(input.to_bytes(), block_size=1024),
    b"\x72\x73\x01\x47\x00\x00\x04\x00\x00\x00\x00\x20\x5a\x37\x03\x01\x0c\xf3\xaa\xd3\xc4\xff\x3e\x58\x43\x30\x30\x32\x0a\x50\x03\x1c\xf4\x97\x21\xab\x44\xe5\xc9\xe8\xa8\xf2\x40\xa4\xc9\xb7\x3d\x52",
  )
}
