///|
fn roundtrip(basis : Bytes, target : Bytes, block_size : Int32) -> Bytes raise {
  let signature = @moonrdiff.parse_signature(
    @moonrdiff.signature(basis, block_size~),
  )
  let delta = @moonrdiff.delta(signature, target, basis_size=basis.length())
  assert_eq(@moonrdiff.patch(basis, delta, max_output=target.length()), target)
  assert_eq(
    @moonrdiff.delta(signature, target, basis_size=basis.length()),
    delta,
  )
  delta
}

///|
test "shift insertion deletion and relocated short tail" {
  for
    (basis, target) in [
      (b"", b""),
      (b"", b"new bytes"),
      (b"old", b""),
      (b"abcdefghijk", b"!abcdefghijk!"),
      (b"abcdefghijk", b"ijkabcdefgh"),
      (b"abcdefghijk", b"abcdhijk"),
      (b"abcabcabcabc", b"abc!abcabcabc"),
      (b"0123456789abcdef", b"89abcdef01234567"),
    ] {
    for block_size in [1, 4, 8, 32, 128] {
      ignore(roundtrip(basis, target, block_size))
    }
  }
  let unchanged = b"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  assert_true(roundtrip(unchanged, unchanged, 4).length() < unchanged.length())
}

///|
test "generated edits with reproducible inputs" {
  for seed in 0..<128 {
    let basis_buffer = @buffer.Buffer()
    for i in 0..<(seed % 63) {
      basis_buffer.write_byte(((i * 37 + seed) % 251).to_byte())
    }
    let basis = basis_buffer.to_bytes()
    let cut = basis.length() / 3
    let target_buffer = @buffer.Buffer()
    target_buffer.write_bytes(b"prefix")
    target_buffer.write_bytes(basis[cut:basis.length()])
    target_buffer.write_bytes(b"insert")
    target_buffer.write_bytes(basis[0:cut])
    let target = target_buffer.to_bytes()
    for block_size in [1, 4, 8, 32, 128] {
      ignore(roundtrip(basis, target, block_size))
    }
  }
}

///|
test "comparison budget falls back to literal and byte budget rejects" {
  let basis = b"abcdefghijk"
  let target = b"abcdefghijkabcdefghijk"
  let signature = @moonrdiff.parse_signature(
    @moonrdiff.signature(basis, block_size=4),
  )
  assert_eq(
    @moonrdiff.delta(signature, target, basis_size=11, max_candidate_checks=0),
    @moonrdiff.encode([Literal(target)]),
  )
  let limited = @moonrdiff.delta(
    signature,
    target,
    basis_size=11,
    max_candidate_checks=1,
  )
  assert_eq(
    @moonrdiff.patch(basis, limited, max_output=target.length()),
    target,
  )
  for
    (basis_size, checks, limit) in [
      (0, 1, 100),
      (-1, 1, 100),
      (11, -1, 100),
      (11, 1, 4),
      (11, 0, 5),
    ] {
    let rejected = try {
      ignore(
        @moonrdiff.delta(
          signature,
          target,
          basis_size~,
          max_candidate_checks=checks,
          max_delta_size=limit,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "weak checksum alone never authorizes copy" {
  let basis = b"abcdefgh"
  let original = @moonrdiff.signature(basis, block_size=8)
  let bad = @buffer.Buffer()
  bad.write_bytes(original[0:16])
  for _ in 0..<32 {
    bad.write_byte(b'\x00')
  }
  let signature = @moonrdiff.parse_signature(bad.to_bytes())
  assert_eq(
    @moonrdiff.delta(signature, basis, basis_size=8),
    @moonrdiff.encode([Literal(basis)]),
  )
}
