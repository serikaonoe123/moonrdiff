///|
fn streamed_delta(
  basis : Bytes,
  target : Bytes,
  block_size : Int32,
  chunk_size : Int32,
  checks : Int32,
) -> Bytes raise {
  let sig = @moonrdiff.parse_signature(@moonrdiff.signature(basis, block_size~))
  let encoder = @moonrdiff.DeltaEncoder::new(
    sig,
    basis_size=basis.length(),
    max_candidate_checks=checks,
  )
  let out = @buffer.Buffer()
  out.write_bytes(encoder.push(b""))
  let mut pos = 0
  while pos < target.length() {
    let left = target.length() - pos
    let n = if chunk_size < left { chunk_size } else { left }
    out.write_bytes(encoder.push(target[pos:pos + n]))
    pos += n
  }
  out.write_bytes(encoder.finish())
  let result = out.to_bytes()
  assert_eq(@moonrdiff.patch(basis, result, max_output=target.length()), target)
  if target.length() < 65536 {
    assert_eq(
      result,
      @moonrdiff.delta(
        sig,
        target,
        basis_size=basis.length(),
        max_candidate_checks=checks,
      ),
    )
  }
  result
}

///|
test "streamed matching preserves boundaries tails and global budgets" {
  for
    (basis, target) in [
      (b"", b""),
      (b"", b"new"),
      (b"abc", b""),
      (b"abcdefghijk", b"!ijkabcdefgh!"),
      (b"abcdefghijk", b"abcdhijk"),
      (b"abcabcabcabc", b"abc!abcabcabc"),
    ] {
    for block_size in [1, 4, 8, 32] {
      for chunk_size in [1, 2, 7, 65536] {
        for checks in [0, 1, 10000] {
          ignore(streamed_delta(basis, target, block_size, chunk_size, checks))
        }
      }
    }
  }
  for seed in 0..<32 {
    let basis_buf = @buffer.Buffer()
    for i in 0..<(seed * 3) {
      basis_buf.write_byte(((i * 37 + seed) % 251).to_byte())
    }
    let basis = basis_buf.to_bytes()
    let target = @buffer.Buffer()
    let cut = basis.length() / 3
    target.write_bytes(b"prefix")
    target.write_bytes(basis[cut:basis.length()])
    target.write_bytes(b"insert")
    target.write_bytes(basis[0:cut])
    for block_size in [1, 4, 8, 32] {
      ignore(streamed_delta(basis, target.to_bytes(), block_size, 7, 10000))
    }
  }
}

///|
test "long literals use fixed batches and lifecycle failures poison state" {
  let target = Bytes::make(131073, b'x')
  assert_eq(
    streamed_delta(b"", target, 32, 7, 0),
    streamed_delta(b"", target, 32, 65536, 0),
  )
  let sig = @moonrdiff.parse_signature(
    @moonrdiff.signature(b"abc", block_size=4),
  )
  let finished = @moonrdiff.DeltaEncoder::new(sig, basis_size=3)
  ignore(finished.finish())
  assert_true(
    try {
      ignore(finished.push(b""))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(finished.finish())
      false
    } catch {
      _ => true
    },
  )
  let limited = @moonrdiff.DeltaEncoder::new(
    sig,
    basis_size=3,
    max_delta_size=5,
  )
  ignore(limited.push(b"x"))
  assert_true(
    try {
      ignore(limited.finish())
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
  let input_limit = @moonrdiff.DeltaEncoder::new(
    sig,
    basis_size=3,
    max_target_size=1,
  )
  assert_true(
    try {
      ignore(input_limit.push(b"xx"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(input_limit.finish())
      false
    } catch {
      _ => true
    },
  )
  let large = @moonrdiff.DeltaEncoder::new(sig, basis_size=3)
  assert_true(
    try {
      ignore(large.push(Bytes::make(65537, b'x')))
      false
    } catch {
      _ => true
    },
  )
  for
    (basis_size, checks, limit, target_size) in [
      (0, 1, 100, 10),
      (-1, 1, 100, 10),
      (3, -1, 100, 10),
      (3, 1, 4, 10),
      (3, 1, 100, -1),
    ] {
    assert_true(
      try {
        ignore(
          @moonrdiff.DeltaEncoder::new(
            sig,
            basis_size~,
            max_candidate_checks=checks,
            max_delta_size=limit,
            max_target_size=target_size,
          ),
        )
        false
      } catch {
        _ => true
      },
    )
  }
}
