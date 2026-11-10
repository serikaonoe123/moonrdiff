///| Incremental signature encoder. Input blocks <= 1 MiB; pushes <= 64 KiB.

///|
/// Each push returns only newly encoded bytes, which the caller must drain.
pub struct SignatureEncoder {
  priv block_size : Int32
  priv strong_length : Int32
  priv max_blocks : Int32
  priv max_output : Int32
  priv pending : Array[Byte]
  priv mut used : Int32
  priv mut blocks : Int32
  priv mut output_size : Int32
  priv mut started : Bool
  priv mut closed : Bool
  priv mut failed : Bool
}

///|
pub fn SignatureEncoder::new(
  block_size~ : Int32 = 2048,
  strong_length~ : Int32 = 32,
  max_blocks~ : Int32 = 1000000,
  max_output~ : Int32 = 67108864,
) -> SignatureEncoder raise DeltaError {
  guard block_size >= 1 &&
    block_size <= 1048576 &&
    strong_length >= 1 &&
    strong_length <= 32 &&
    max_blocks >= 0 &&
    max_output >= 12 else {
    raise Invalid("Invalid streaming signature configuration")
  }
  {
    block_size,
    strong_length,
    max_blocks,
    max_output,
    pending: Array::make(block_size, b'\x00'),
    used: 0,
    blocks: 0,
    output_size: 0,
    started: false,
    closed: false,
    failed: false,
  }
}

///|
pub fn SignatureEncoder::buffered_bytes(self : SignatureEncoder) -> Int32 {
  self.used
}

///|
pub fn SignatureEncoder::output_bytes(self : SignatureEncoder) -> Int32 {
  self.output_size
}

///|
fn SignatureEncoder::header(
  self : SignatureEncoder,
  out : @buffer.Buffer,
) -> Unit {
  if !self.started {
    out.write_bytes(b"rs\x01G")
    write_u32(out, self.block_size)
    write_u32(out, self.strong_length)
    self.started = true
    self.output_size = 12
  }
}

///|
fn SignatureEncoder::record(
  self : SignatureEncoder,
  out : @buffer.Buffer,
) -> Unit raise DeltaError {
  guard self.blocks < self.max_blocks &&
    self.max_output - self.output_size >= 4 + self.strong_length else {
    raise Invalid("Streaming signature budget exceeded")
  }
  let bytes = Bytes::from_array(self.pending[0:self.used])
  write_weak(out, rk_checksum(bytes))
  let strong = @crypto.blake2b(bytes, 32)
  out.write_bytes(strong[0:self.strong_length])
  self.blocks += 1
  self.output_size += 4 + self.strong_length
  self.used = 0
}

///|
/// Failed pushes poison the encoder; callers must discard partial output.
pub fn SignatureEncoder::push(
  self : SignatureEncoder,
  chunk : BytesView,
) -> Bytes raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Signature encoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  guard chunk.length() <= 65536 else {
    raise Invalid("Signature push exceeds 64 KiB")
  }
  let out = @buffer.Buffer()
  self.header(out)
  for byte in chunk {
    self.pending[self.used] = byte
    self.used += 1
    if self.used == self.block_size {
      self.record(out)
    }
  }
  out.to_bytes()
}

///|
/// Emit the final short block; even an empty stream emits a valid header.
pub fn SignatureEncoder::finish(
  self : SignatureEncoder,
) -> Bytes raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Signature encoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  let out = @buffer.Buffer()
  self.header(out)
  if self.used > 0 {
    self.record(out)
  }
  self.closed = true
  out.to_bytes()
}
