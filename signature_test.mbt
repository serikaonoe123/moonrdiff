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
