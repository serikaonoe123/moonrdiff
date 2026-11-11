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
fn corpus_next(state : UInt32) -> UInt32 {
  let a = state ^ (state << 13)
  let b = a ^ (a >> 17)
  b ^ (b << 5)
}

///|
fn corpus_bytes(length : Int32, seed : UInt32, repeated : Bool) -> Bytes {
  let out = @buffer.Buffer()
  let mut state = seed
  for i in 0..<length {
    state = corpus_next(state)
    let byte = if repeated {
      (i % 7 * 41).to_byte()
    } else {
      (state & 255U).reinterpret_as_int().to_byte()
    }
    out.write_byte(byte)
  }
  out.to_bytes()
}

///|
/// Two independent push partitions must produce the same delta, including when
/// empty pushes interleave data and a literal spans the 64 KiB flush boundary.
fn partitioned_update(
  basis : Bytes,
  target : Bytes,
  block_size : Int32,
  strong_length : Int32,
  checks : Int32,
  partition_seed : UInt32,
  delta_limit~ : Int32 = 16777216,
) -> Bytes raise {
  let chunks = [
    1, 2, 3, 7, 31, 63, 64, 127, 128, 129, 255, 256, 257, 4093, 65535, 65536,
  ]
  let mut state = partition_seed
  let blocks = basis.length() / block_size +
    (if basis.length() % block_size == 0 { 0 } else { 1 })
  let signature_encoder = @moonrdiff.SignatureEncoder::new(
    block_size~,
    strong_length~,
    max_blocks=blocks,
    max_output=12 + blocks * (4 + strong_length),
  )
  let signature_bytes = @buffer.Buffer()
  signature_bytes.write_bytes(signature_encoder.push(b""))
  let mut position = 0
  while position < basis.length() {
    state = corpus_next(state)
    let size = if partition_seed == 0U {
      65536
    } else {
      chunks[(state & 15U).reinterpret_as_int()]
    }
    let left = basis.length() - position
    let n = if size < left { size } else { left }
    signature_bytes.write_bytes(
      signature_encoder.push(basis[position:position + n]),
    )
    signature_bytes.write_bytes(signature_encoder.push(b""))
    position += n
  }
  signature_bytes.write_bytes(signature_encoder.finish())
  let encoded_signature = signature_bytes.to_bytes()
  assert_eq(
    encoded_signature,
    @moonrdiff.signature(basis, block_size~, strong_length~),
  )
  assert_eq(signature_encoder.output_bytes(), encoded_signature.length())
  assert_eq(signature_encoder.buffered_bytes(), 0)
  let signature = @moonrdiff.parse_signature(encoded_signature)
  let encoder = @moonrdiff.DeltaEncoder::new(
    signature,
    basis_size=basis.length(),
    max_candidate_checks=checks,
    max_delta_size=delta_limit,
    max_target_size=target.length(),
  )
  let delta = @buffer.Buffer()
  delta.write_bytes(encoder.push(b""))
  position = 0
  while position < target.length() {
    state = corpus_next(state)
    let size = if partition_seed == 0U {
      65536
    } else {
      chunks[(state & 15U).reinterpret_as_int()]
    }
    let left = target.length() - position
    let n = if size < left { size } else { left }
    delta.write_bytes(encoder.push(target[position:position + n]))
    delta.write_bytes(encoder.push(b""))
    position += n
  }
  delta.write_bytes(encoder.finish())
  let bytes = delta.to_bytes()
  assert_eq(@moonrdiff.patch(basis, bytes, max_output=target.length()), target)
  let decoder = @moonrdiff.PatchDecoder::new(
    basis_size=basis.length(),
    max_output=target.length(),
  )
  let restored = @buffer.Buffer()
  assert_true(decoder.push(b"").is_empty())
  position = 0
  while position < bytes.length() {
    state = corpus_next(state)
    let size = if partition_seed == 0U {
      65536
    } else {
      chunks[(state & 15U).reinterpret_as_int()]
    }
    let left = bytes.length() - position
    let n = if size < left { size } else { left }
    for part in decoder.push(bytes[position:position + n]) {
      match part {
        Literal(data) => restored.write_bytes(data)
        Copy(offset~, length~) =>
          restored.write_bytes(basis[offset:offset + length])
      }
    }
    assert_true(decoder.push(b"").is_empty())
    position += n
  }
  decoder.finish()
  assert_eq(restored.to_bytes(), target)
  bytes
}

///|
test "seeded edit corpus preserves the complete partitioned update pipeline" {
  let lengths = [
    0, 1, 31, 32, 33, 127, 128, 129, 255, 256, 257, 2047, 2048, 2049, 4097, 65535,
    65536, 65537, 131073,
  ]
  for seed in 1..<=38 {
    let length = lengths[(seed - 1) % lengths.length()]
    let basis = corpus_bytes(length, seed.reinterpret_as_uint(), seed % 4 == 3)
    let target = @buffer.Buffer()
    if seed % 4 == 0 {
      target.write_bytes(basis)
    } else if seed % 4 == 2 {
      target.write_bytes(
        corpus_bytes(length + 35, (seed + 7919).reinterpret_as_uint(), false),
      )
    } else {
      let cut = length / 3
      let end = length - length / 7
      target.write_bytes(b"\x00\xffprefix")
      target.write_bytes(basis[cut:end])
      target.write_bytes(
        corpus_bytes(17, (seed + 65537).reinterpret_as_uint(), false),
      )
      target.write_bytes(basis[0:cut])
      target.write_bytes(basis[end:length])
      target.write_bytes(basis[0:cut])
    }
    let target = target.to_bytes()
    let block_size = if length > 4097 {
      [127, 128, 2048][seed % 3]
    } else {
      [1, 3, 32, 128, 2048][seed % 5]
    }
    let strong_length = [1, 16, 32][seed % 3]
    let checks = [0, 1, 1000000][seed % 3]
    let reference = partitioned_update(
      basis, target, block_size, strong_length, checks, 0U,
    )
    let partitioned = partitioned_update(
      basis,
      target,
      block_size,
      strong_length,
      checks,
      seed.reinterpret_as_uint(),
      delta_limit=reference.length(),
    )
    if partitioned != reference {
      fail("Chunk partition changed delta for corpus seed \{seed}")
    }
    let signature = @moonrdiff.parse_signature(
      @moonrdiff.signature(basis, block_size~, strong_length~),
    )
    let whole = @moonrdiff.delta(
      signature,
      target,
      basis_size=basis.length(),
      max_candidate_checks=checks,
    )
    assert_eq(
      @moonrdiff.patch(basis, whole, max_output=target.length()),
      target,
    )
  }
}

///|
test "exact streamed literal budget succeeds and one byte less fails" {
  for length in [63, 64, 65, 255, 256, 257, 65535, 65536, 65537] {
    let target = corpus_bytes(length, 20261111U, false)
    let reference = partitioned_update(b"", target, 128, 32, 0, 0U)
    assert_eq(
      partitioned_update(
        b"",
        target,
        128,
        32,
        0,
        17U,
        delta_limit=reference.length(),
      ),
      reference,
    )
    assert_true(
      try {
        ignore(
          partitioned_update(
            b"",
            target,
            128,
            32,
            0,
            17U,
            delta_limit=reference.length() - 1,
          ),
        )
        false
      } catch {
        @moonrdiff.DeltaError::Invalid(_) => true
        _ => false
      },
    )
  }
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
    for block_size in [1, 3, 4, 7, 8, 17, 32] {
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
    for block_size in [1, 3, 4, 7, 8, 17, 32] {
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
