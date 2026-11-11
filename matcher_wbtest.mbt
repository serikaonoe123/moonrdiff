///|
/// Compare each rolling update with a freshly evaluated polynomial.
test "rolling polynomial equals recomputation" {
  let buffer = @buffer.Buffer()
  for i in 0..<512 {
    buffer.write_byte(((i * 73 + 255) % 256).to_byte())
  }
  let input = buffer.to_bytes()
  for length in [1, 2, 7, 32, 127, 128, 255] {
    let mut checksum = rk_checksum(input[0:length])
    for position in 0..<(input.length() - length) {
      checksum = rk_slide(
        checksum,
        input[position],
        input[position + length],
        rk_power(length),
      )
      assert_eq(
        checksum,
        rk_checksum(input[position + 1:position + 1 + length]),
      )
    }
  }
}

///|
test "stream prefilter retains every indexed key and caps its allocation" {
  for count in [0, 1, 64, 65, 16384, 16385, 40000] {
    let blocks : Array[BlockSignature] = []
    for i in 0..<count {
      blocks.push({
        weak: (i.reinterpret_as_uint() * 0x9e3779b9U) ^ 0xf8000000U,
        strong: Bytes::make(32, b'\x00'),
      })
    }
    let sig = Signature::{ block_size: 4, strong_length: 32, blocks, }
    let encoder = DeltaEncoder::new(sig, basis_size=count * 4)
    assert_true(encoder.prefilter.length() >= 64)
    assert_true(encoder.prefilter.length() <= 16384)
    for block in blocks {
      let slot = (block.weak & encoder.filter_mask).reinterpret_as_int()
      let bit = 1U << ((block.weak >> 16) & 31U).reinterpret_as_int()
      assert_true((encoder.prefilter[slot] & bit) != 0U)
    }
  }
}

///|
test "stream prefilter collision still requires the original index lookup" {
  let weak = rk_checksum(b"abcd")
  let sig = Signature::{
    block_size: 4,
    strong_length: 32,
    blocks: [{ weak: weak ^ (1U << 21), strong: Bytes::make(32, b'\x00'), }],
  }
  let encoder = DeltaEncoder::new(sig, basis_size=4)
  let slot = (weak & encoder.filter_mask).reinterpret_as_int()
  let bit = 1U << ((weak >> 16) & 31U).reinterpret_as_int()
  assert_true((encoder.prefilter[slot] & bit) != 0U)
  assert_true(encoder.index.get(weak) is None)
  let output = @buffer.Buffer()
  output.write_bytes(encoder.push(b"abcd"))
  output.write_bytes(encoder.finish())
  assert_eq(output.to_bytes(), encode([Literal(b"abcd")]))
}
