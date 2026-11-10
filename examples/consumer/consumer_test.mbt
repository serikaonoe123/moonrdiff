///|
/// Consumer imports public root APIs only; no private implementation imports.
test "public API in-memory update" {
  let basis = b"abcdefghijk"
  let target = b"prefix-ijkabcdefgh-suffix"
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
