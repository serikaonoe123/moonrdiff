///| Incremental matcher; signature index scales with basis blocks, target buffer

///|
/// is at most one block and literals at most 64 KiB. Drain every returned batch.
pub struct DeltaEncoder {
  priv signature : Signature
  priv index : Map[UInt32, Array[Int32]]
  priv tail : Int32
  priv tail_power : UInt32
  priv full_count : Int32
  priv max_checks : Int32
  priv max_target : Int32
  priv ring : Array[Byte]
  priv literals : Array[Byte]
  priv writer : DeltaWriter
  priv mut head : Int32
  priv mut count : Int32
  priv mut weak : UInt32
  priv mut power : UInt32
  priv mut tail_weak : UInt32
  priv mut checks : Int32
  priv mut received : Int32
  priv mut closed : Bool
  priv mut failed : Bool
}

///|
pub fn DeltaEncoder::new(
  signature : Signature,
  basis_size~ : Int32,
  max_candidate_checks~ : Int32 = 1000000,
  max_delta_size~ : Int32 = 16777216,
  max_target_size~ : Int32 = 67108864,
) -> DeltaEncoder raise DeltaError {
  let b = signature.block_size
  guard basis_size >= 0 &&
    b <= 1048576 &&
    max_candidate_checks >= 0 &&
    max_delta_size >= 5 &&
    max_target_size >= 0 else {
    raise Invalid("Invalid incremental delta configuration")
  }
  let full_count = basis_size / b
  let tail = basis_size % b
  guard full_count + (if tail == 0 { 0 } else { 1 }) ==
    signature.blocks.length() else {
    raise Invalid("Basis size disagrees with signature count")
  }
  let index : Map[UInt32, Array[Int32]] = Map([])
  for i in 0..<full_count {
    let weak = signature.blocks[i].weak
    match index.get(weak) {
      Some(values) => values.push(i)
      None => index[weak] = [i]
    }
  }
  let writer = DeltaWriter::{
    out: @buffer.Buffer(),
    limit: max_delta_size - 1,
    size: 4,
    copy_offset: 0,
    copy_length: 0,
  }
  writer.out.write_bytes(b"rs\x02\x36")
  {
    signature,
    index,
    tail,
    tail_power: rk_power(tail),
    full_count,
    max_checks: max_candidate_checks,
    max_target: max_target_size,
    ring: Array::make(b, b'\x00'),
    literals: [],
    writer,
    head: 0,
    count: 0,
    weak: 1U,
    power: 1U,
    tail_weak: 1U,
    checks: 0,
    received: 0,
    closed: false,
    failed: false,
  }
}

///|
fn DeltaEncoder::byte(self : DeltaEncoder, index : Int32) -> Byte {
  // head and index are each below block_size, so at most one wrap is needed.
  let slot = self.head + index
  self.ring[if slot >= self.signature.block_size {
    slot - self.signature.block_size
  } else {
    slot
  }]
}

///|
fn DeltaEncoder::window(self : DeltaEncoder, length : Int32) -> Bytes {
  let out = @buffer.Buffer()
  for i in 0..<length {
    out.write_byte(self.byte(i))
  }
  out.to_bytes()
}

///|
/// Remove the first byte of the seeded polynomial window in O(1).
fn DeltaEncoder::pop(self : DeltaEncoder) -> Unit {
  let out = self.byte(0)
  let next_power = self.power * 0x98f009adU // inverse of M modulo 2^32
  self.weak -= next_power * (out.to_uint() + 0x08104224U)
  if self.tail > 0 && self.count > self.tail {
    self.tail_weak = rk_slide(
      self.tail_weak,
      out,
      self.byte(self.tail),
      self.tail_power,
    )
  } else {
    self.tail_weak = self.weak
  }
  self.head = if self.head + 1 == self.signature.block_size {
    0
  } else {
    self.head + 1
  }
  self.count -= 1
  self.power = next_power
}

///|
fn DeltaEncoder::flush_literals(self : DeltaEncoder) -> Unit raise DeltaError {
  if !self.literals.is_empty() {
    self.writer.literal(Bytes::from_array(self.literals[:]))
    self.literals.clear()
  }
}

///|
/// Process one full lookahead window, or a shorter window only at EOF.
fn DeltaEncoder::step(self : DeltaEncoder) -> Unit raise DeltaError {
  let mut matched = -1
  let mut length = self.signature.block_size
  if self.count == length && self.checks < self.max_checks {
    match self.index.get(self.weak) {
      Some(indices) => {
        let strong = @crypto.blake2b(self.window(length), 32)
        for i in indices {
          if self.checks >= self.max_checks {
            break
          }
          self.checks += 1
          if strong[0:self.signature.strong_length] ==
            self.signature.blocks[i].strong {
            matched = i
            break
          }
        }
      }
      None => ()
    }
  }
  if matched < 0 &&
    self.tail > 0 &&
    self.count >= self.tail &&
    self.checks < self.max_checks &&
    self.tail_weak == self.signature.blocks[self.full_count].weak {
    self.checks += 1
    let strong = @crypto.blake2b(self.window(self.tail), 32)
    if strong[0:self.signature.strong_length] ==
      self.signature.blocks[self.full_count].strong {
      matched = self.full_count
      length = self.tail
    }
  }
  if matched >= 0 {
    self.flush_literals()
    self.writer.copy(matched * self.signature.block_size, length)
    if length == self.count {
      self.head = 0
      self.count = 0
      self.weak = 1U
      self.power = 1U
      self.tail_weak = 1U
    } else {
      for _ in 0..<length {
        self.pop()
      }
    }
  } else {
    self.literals.push(self.byte(0))
    self.pop()
    if self.literals.length() == 65536 {
      self.flush_literals()
    }
  }
}

///|
fn DeltaEncoder::drain(self : DeltaEncoder) -> Bytes {
  let bytes = self.writer.out.to_bytes()
  self.writer.out = @buffer.Buffer()
  bytes
}

///|
/// Failure poisons the encoder. Literal fallback shares one global budget.
pub fn DeltaEncoder::push(
  self : DeltaEncoder,
  chunk : BytesView,
) -> Bytes raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Delta encoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  guard chunk.length() <= 65536 &&
    chunk.length() <= self.max_target - self.received else {
    raise Invalid("Delta target input budget exceeded")
  }
  self.received += chunk.length()
  for byte in chunk {
    let slot = self.head + self.count
    self.ring[if slot >= self.signature.block_size {
      slot - self.signature.block_size
    } else {
      slot
    }] = byte
    if self.count < self.tail {
      self.tail_weak = self.tail_weak * 0x08104225U + byte.to_uint()
    }
    self.weak = self.weak * 0x08104225U + byte.to_uint()
    self.power *= 0x08104225U
    self.count += 1
    if self.count == self.signature.block_size {
      self.step()
    }
  }
  self.drain()
}

///|
pub fn DeltaEncoder::finish(self : DeltaEncoder) -> Bytes raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Delta encoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  while self.count > 0 {
    self.step()
  }
  self.flush_literals()
  self.writer.flush_copy()
  self.writer.out.write_byte(b'\x00')
  self.closed = true
  self.drain()
}
