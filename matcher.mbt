///|
fn rk_power(length : Int32) -> UInt32 {
  let mut power = 1U
  let mut factor = 0x08104225U
  let mut n = length
  while n > 0 {
    if n % 2 == 1 {
      power *= factor
    }
    factor *= factor
    n = n / 2
  }
  power
}

///|
/// Update the seeded polynomial for a fixed-length sliding window.
fn rk_slide(
  hash : UInt32,
  outgoing : Byte,
  incoming : Byte,
  power : UInt32,
) -> UInt32 {
  hash * 0x08104225U +
  incoming.to_uint() -
  power * (outgoing.to_uint() + 0x08104224U)
}

///|
priv struct DeltaWriter {
  out : @buffer.Buffer
  limit : Int32
  mut size : Int32
  mut copy_offset : Int32
  mut copy_length : Int32
}

///|
fn DeltaWriter::flush_copy(self : DeltaWriter) -> Unit raise DeltaError {
  if self.copy_length > 0 {
    guard self.limit - self.size >= 9 else {
      raise Invalid("Delta byte budget exceeded")
    }
    self.out.write_byte(b'\x4f')
    write_u32(self.out, self.copy_offset)
    write_u32(self.out, self.copy_length)
    self.size += 9
    self.copy_length = 0
  }
}

///|
fn DeltaWriter::copy(
  self : DeltaWriter,
  offset : Int32,
  length : Int32,
) -> Unit raise DeltaError {
  if self.copy_length > 0 && self.copy_offset + self.copy_length == offset {
    self.copy_length += length
  } else {
    self.flush_copy()
    self.copy_offset = offset
    self.copy_length = length
  }
}

///|
fn DeltaWriter::literal(
  self : DeltaWriter,
  bytes : BytesView,
) -> Unit raise DeltaError {
  if bytes.length() == 0 {
    return
  }
  self.flush_copy()
  let header = if bytes.length() <= 64 { 1 } else { 5 }
  guard bytes.length() <= self.limit - self.size - header else {
    raise Invalid("Delta byte budget exceeded")
  }
  if header == 1 {
    self.out.write_byte(bytes.length().to_byte())
  } else {
    self.out.write_byte(b'\x43')
    write_u32(self.out, bytes.length())
  }
  self.out.write_bytes(bytes)
  self.size += header + bytes.length()
}

///| Generate a delta using only a validated signature and target bytes.

///| basis_size is caller-supplied metadata, required to locate the short tail.

///|
/// Once the comparison budget is exhausted, remaining bytes become literals.
pub fn delta(
  signature : Signature,
  target : Bytes,
  basis_size~ : Int32,
  max_candidate_checks~ : Int32 = 1000000,
  max_delta_size~ : Int32 = 16777216,
) -> Bytes raise DeltaError {
  guard basis_size >= 0 && max_candidate_checks >= 0 && max_delta_size >= 5 else {
    raise Invalid("Invalid delta configuration")
  }
  let block_size = signature.block_size
  let count = basis_size / block_size +
    (if basis_size % block_size == 0 { 0 } else { 1 })
  guard count == signature.blocks.length() else {
    raise Invalid("Basis size disagrees with signature count")
  }
  let tail = basis_size % block_size
  let full_count = basis_size / block_size
  let index : Map[UInt32, Array[Int32]] = Map([])
  for i in 0..<full_count {
    let weak = signature.blocks[i].weak
    match index.get(weak) {
      Some(indices) => indices.push(i)
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
  let power = rk_power(block_size)
  let tail_power = rk_power(tail)
  let mut position = 0
  let mut literal_start = 0
  let mut checks = 0
  let mut weak = if target.length() >= block_size {
    rk_checksum(target[0:block_size])
  } else {
    0U
  }
  let mut tail_weak = if tail > 0 && target.length() >= tail {
    rk_checksum(target[0:tail])
  } else {
    0U
  }
  while position < target.length() && checks < max_candidate_checks {
    let remaining = target.length() - position
    let mut matched = -1
    let mut length = block_size
    if remaining >= block_size {
      match index.get(weak) {
        Some(indices) => {
          let strong = @crypto.blake2b(
            target[position:position + block_size].to_owned(),
            32,
          )
          for i in indices {
            if checks >= max_candidate_checks {
              break
            }
            checks += 1
            if strong[0:signature.strong_length] == signature.blocks[i].strong {
              matched = i
              break
            }
          }
        }
        None => ()
      }
    }
    if matched < 0 &&
      tail > 0 &&
      remaining >= tail &&
      checks < max_candidate_checks &&
      tail_weak == signature.blocks[full_count].weak {
      checks += 1
      let strong = @crypto.blake2b(
        target[position:position + tail].to_owned(),
        32,
      )
      if strong[0:signature.strong_length] ==
        signature.blocks[full_count].strong {
        matched = full_count
        length = tail
      }
    }
    if matched >= 0 {
      writer.literal(target[literal_start:position])
      writer.copy(matched * block_size, length)
      position += length
      literal_start = position
      let next_remaining = target.length() - position
      weak = if next_remaining >= block_size {
        rk_checksum(target[position:position + block_size])
      } else {
        0U
      }
      tail_weak = if tail > 0 && next_remaining >= tail {
        rk_checksum(target[position:position + tail])
      } else {
        0U
      }
    } else {
      if remaining > block_size {
        weak = rk_slide(
          weak,
          target[position],
          target[position + block_size],
          power,
        )
      }
      if tail > 0 && remaining > tail {
        tail_weak = rk_slide(
          tail_weak,
          target[position],
          target[position + tail],
          tail_power,
        )
      }
      position += 1
    }
  }
  writer.literal(target[literal_start:target.length()])
  writer.flush_copy()
  writer.out.write_byte(b'\x00')
  writer.out.to_bytes()
}
