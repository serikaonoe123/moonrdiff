///|
/// Consumer imports public root APIs only; no private implementation imports.
test "public API in-memory update" {
  let basis = b"abcdefghijk"
  let target = b"prefix-abcdefghijk-suffix"
  let signature = @rdiff.parse_signature(@rdiff.signature(basis, block_size=4))
  let delta = @rdiff.delta(signature, target, basis_size=basis.length())
  assert_eq(@rdiff.patch(basis, delta, max_output=target.length()), target)
}

///|
test "public incremental API across separate input and output batches" {
  let basis = b"abcdefghijk"
  let target = b"!ijkabcdefgh!"
  let signer = @rdiff.SignatureEncoder::new(block_size=4)
  let sig = @buffer.Buffer()
  sig.write_bytes(signer.push(basis[0:3]))
  sig.write_bytes(signer.push(basis[3:basis.length()]))
  sig.write_bytes(signer.finish())
  let encoder = @rdiff.DeltaEncoder::new(
    @rdiff.parse_signature(sig.to_bytes()),
    basis_size=basis.length(),
  )
  let delta = @buffer.Buffer()
  for byte in target {
    delta.write_bytes(encoder.push(Bytes::make(1, byte)))
  }
  delta.write_bytes(encoder.finish())
  let decoder = @rdiff.PatchDecoder::new(
    basis_size=basis.length(),
    max_output=target.length(),
  )
  let restored = @buffer.Buffer()
  for byte in delta.to_bytes() {
    for part in decoder.push(Bytes::make(1, byte)) {
      match part {
        @rdiff.Literal(bytes) => restored.write_bytes(bytes)
        @rdiff.Copy(offset~, length~) =>
          restored.write_bytes(basis[offset:offset + length])
      }
    }
  }
  decoder.finish()
  assert_eq(restored.to_bytes(), target)
}

///|
fn is_invalid(action : () -> Unit raise @rdiff.DeltaError) -> Bool {
  try {
    action()
    false
  } catch {
    @rdiff.Invalid(message) => !message.is_empty()
  }
}

///|
test "public defaults counters and empty stream completion" {
  let expected = b"rs\x01G\x00\x00\x08\x00\x00\x00\x00\x20"
  assert_eq(@rdiff.signature(b""), expected)
  let signer = @rdiff.SignatureEncoder::new()
  assert_eq(signer.buffered_bytes(), 0)
  assert_eq(signer.output_bytes(), 0)
  assert_eq(signer.finish(), expected)
  assert_eq(signer.output_bytes(), 12)
  let parsed = @rdiff.parse_signature(expected)
  assert_eq(parsed.block_count(), 0)
  assert_eq(parsed.to_bytes(), expected)
  let encoder = @rdiff.DeltaEncoder::new(
    @rdiff.parse_signature(expected), basis_size=0,
  )
  let delta = encoder.finish()
  assert_eq(delta, b"rs\x02\x36\x00")
  let decoder = @rdiff.PatchDecoder::new(basis_size=0, max_output=0)
  assert_eq(decoder.push(delta).length(), 0)
  decoder.finish()
}

///|
test "public typed errors and failed or finished instance rejection" {
  let signer = @rdiff.SignatureEncoder::new(block_size=4)
  ignore(signer.push(b"ab"))
  assert_eq(signer.buffered_bytes(), 2)
  assert_eq(signer.output_bytes(), 12)
  ignore(signer.finish())
  assert_eq(signer.buffered_bytes(), 0)
  assert_eq(signer.output_bytes(), 48)
  assert_true(is_invalid(() => { ignore(signer.push(b"")) }))
  assert_true(is_invalid(() => { ignore(signer.finish()) }))
  let failed = @rdiff.SignatureEncoder::new()
  assert_true(is_invalid(() => { ignore(failed.push(Bytes::make(65537, b'x'))) }))
  assert_true(is_invalid(() => { ignore(failed.finish()) }))
  let decoder = @rdiff.PatchDecoder::new(basis_size=0, max_output=2)
  let delta = @rdiff.encode([@rdiff.Literal(b"ab")])
  // Received bytes are provisional: the mandatory END was not supplied.
  assert_eq(decoder.push(delta[0:delta.length() - 1]).length(), 1)
  assert_true(is_invalid(() => { decoder.finish() }))
  assert_true(is_invalid(() => { ignore(decoder.push(b"\x00")) }))
}

///|
test "public budgets accumulate across push boundaries" {
  let encoder = @rdiff.DeltaEncoder::new(
    @rdiff.parse_signature(@rdiff.signature(b"")),
    basis_size=0, max_target_size=3,
  )
  ignore(encoder.push(b"ab"))
  assert_true(is_invalid(() => { ignore(encoder.push(b"cd")) }))
  assert_true(is_invalid(() => { ignore(encoder.finish()) }))
  let delta = @rdiff.encode([@rdiff.Literal(b"ab"), @rdiff.Literal(b"cd")])
  let decoder = @rdiff.PatchDecoder::new(basis_size=0, max_output=3)
  assert_eq(decoder.push(delta[0:7]).length(), 1)
  assert_true(is_invalid(() => { ignore(decoder.push(delta[7:delta.length()])) }))
  assert_true(is_invalid(() => { decoder.finish() }))
}
