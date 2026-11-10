///|
priv struct BlockSignature {
  weak : UInt32
  strong : Bytes
}

///|
/// Validated RK/BLAKE2 signature. Block count does not encode basis file size.
pub struct Signature {
  priv block_size : Int32
  priv strong_length : Int32
  priv blocks : Array[BlockSignature]
}

///|
pub fn Signature::block_count(self : Signature) -> Int32 {
  self.blocks.length()
}

///|
/// Serialize a validated signature without changing its record order.
pub fn Signature::to_bytes(self : Signature) -> Bytes {
  let out = @buffer.Buffer()
  out.write_bytes(b"rs\x01G")
  write_u32(out, self.block_size)
  write_u32(out, self.strong_length)
  for block in self.blocks {
    write_weak(out, block.weak)
    out.write_bytes(block.strong)
  }
  out.to_bytes()
}

///|
/// Polynomial checksum modulo 2^32, seeded with 1.
fn rk_checksum(data : BytesView) -> UInt32 {
  let mut value = 1U
  for byte in data {
    value = value * 0x08104225U + byte.to_uint()
  }
  value
}

///|
fn write_weak(out : @buffer.Buffer, value : UInt32) -> Unit {
  for shift in [24, 16, 8, 0] {
    out.write_byte(((value >> shift) & 255U).to_byte())
  }
}

///|
fn Cursor::weak(self : Cursor) -> UInt32 raise DeltaError {
  guard self.data.length() - self.position >= 4 else {
    raise Invalid("Truncated weak checksum")
  }
  let mut value = 0U
  for _ in 0..<4 {
    value = (value << 8) | self.data[self.position].to_uint()
    self.position += 1
  }
  value
}

///|
/// Generate one supported librsync signature profile in memory.
pub fn signature(
  basis : Bytes,
  block_size~ : Int32 = 2048,
  strong_length~ : Int32 = 32,
  max_blocks~ : Int32 = 1000000,
) -> Bytes raise DeltaError {
  guard block_size > 0 &&
    strong_length >= 1 &&
    strong_length <= 32 &&
    max_blocks >= 0 else {
    raise Invalid("Invalid signature configuration")
  }
  let count = basis.length() / block_size +
    (if basis.length() % block_size == 0 { 0 } else { 1 })
  guard count <= max_blocks && count <= (2147483647 - 12) / (4 + strong_length) else {
    raise Invalid("Signature block budget exceeded")
  }
  let out = @buffer.Buffer()
  out.write_bytes(b"rs\x01G")
  write_u32(out, block_size)
  write_u32(out, strong_length)
  let mut offset = 0
  while offset < basis.length() {
    let remaining = basis.length() - offset
    let length = if block_size < remaining { block_size } else { remaining }
    let block = basis[offset:offset + length]
    write_weak(out, rk_checksum(block))
    // Hash output size is always 32; truncation happens afterwards.
    let strong = @crypto.blake2b(block.to_owned(), 32)
    out.write_bytes(strong[0:strong_length])
    offset += length
  }
  out.to_bytes()
}

///|
/// Parse only RS_RK_BLAKE2 signatures, bounding allocation by block count.
pub fn parse_signature(
  data : Bytes,
  max_blocks~ : Int32 = 1000000,
) -> Signature raise DeltaError {
  guard max_blocks >= 0 && data.length() >= 12 && data[0:4] == b"rs\x01G" else {
    raise Invalid("Unsupported or truncated signature header")
  }
  let cursor = Cursor::{ data, position: 4, }
  let block_size = cursor.integer(4)
  let strong_length = cursor.integer(4)
  guard block_size > 0 && strong_length >= 1 && strong_length <= 32 else {
    raise Invalid("Invalid signature header values")
  }
  let record_size = 4 + strong_length
  guard (data.length() - 12) % record_size == 0 else {
    raise Invalid("Truncated signature block")
  }
  let count = (data.length() - 12) / record_size
  guard count <= max_blocks else {
    raise Invalid("Signature block budget exceeded")
  }
  let blocks : Array[BlockSignature] = []
  for _ in 0..<count {
    let weak = cursor.weak()
    let strong = data[cursor.position:cursor.position + strong_length].to_owned()
    cursor.position += strong_length
    blocks.push({ weak, strong, })
  }
  { block_size, strong_length, blocks, }
}
