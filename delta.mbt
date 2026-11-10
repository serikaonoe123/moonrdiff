///|
/// A description of the target bytes; Copy always addresses the old basis.
pub(all) enum Instruction {
  Literal(Bytes)
  Copy(offset~ : Int32, length~ : Int32)
}

///|
pub suberror DeltaError {
  Invalid(String)
}

///|
fn write_u32(out : @buffer.Buffer, value : Int32) -> Unit {
  for shift in [24, 16, 8, 0] {
    out.write_byte(((value >> shift) & 255).to_byte())
  }
}

///|
/// Encode explicit instructions; this is not yet a matching algorithm.
pub fn encode(instructions : Array[Instruction]) -> Bytes raise DeltaError {
  let out = @buffer.Buffer()
  out.write_bytes(b"rs\x02\x36")
  for instruction in instructions {
    match instruction {
      Literal(data) =>
        if data.length() > 0 {
          if data.length() <= 64 {
            out.write_byte(data.length().to_byte())
          } else {
            out.write_byte(b'\x43')
            write_u32(out, data.length())
          }
          out.write_bytes(data)
        }
      Copy(offset~, length~) => {
        guard offset >= 0 && length > 0 else {
          raise Invalid("Invalid copy range")
        }
        out.write_byte(b'\x4f')
        write_u32(out, offset)
        write_u32(out, length)
      }
    }
  }
  out.write_byte(b'\x00')
  out.to_bytes()
}

///|
priv struct Cursor {
  data : Bytes
  mut position : Int32
}

///|
/// Read a big-endian parameter while bounding it before any index conversion.
fn Cursor::integer(self : Cursor, width : Int32) -> Int32 raise DeltaError {
  guard width <= self.data.length() - self.position else {
    raise Invalid("Truncated integer")
  }
  let mut result = 0
  for _ in 0..<width {
    let byte = self.data[self.position].to_int()
    guard result <= (2147483647 - byte) / 256 else {
      raise Invalid("Parameter exceeds in-memory Int32 limit")
    }
    result = result * 256 + byte
    self.position += 1
  }
  result
}

///| Apply an rdiff delta in memory, with an explicit output budget.

///|
/// Parameters above Int32 capacity are rejected even if valid in the format.
pub fn patch(
  basis : Bytes,
  delta : Bytes,
  max_output~ : Int32,
) -> Bytes raise DeltaError {
  guard max_output >= 0 else { raise Invalid("Negative output budget") }
  guard delta.length() >= 4 && delta[0:4] == b"rs\x02\x36" else {
    raise Invalid("Unsupported delta magic")
  }
  let cursor = Cursor::{ data: delta, position: 4, }
  let out = @buffer.Buffer()
  let mut size = 0
  while cursor.position < delta.length() {
    let op = cursor.integer(1)
    if op == 0 {
      guard cursor.position == delta.length() else {
        raise Invalid("Trailing data after end")
      }
      return out.to_bytes()
    }
    let (offset, length) = if op <= 64 {
      (-1, op)
    } else if op <= 68 {
      (-1, cursor.integer(1 << (op - 65)))
    } else if op <= 84 {
      let code = op - 69
      let offset = cursor.integer(1 << (code / 4))
      (offset, cursor.integer(1 << (code % 4)))
    } else {
      raise Invalid("Reserved delta instruction")
    }
    guard length <= max_output - size else {
      raise Invalid("Output budget exceeded")
    }
    if offset == -1 {
      guard length <= delta.length() - cursor.position else {
        raise Invalid("Truncated literal")
      }
      out.write_bytes(delta[cursor.position:cursor.position + length])
      cursor.position += length
    } else {
      guard offset <= basis.length() && length <= basis.length() - offset else {
        raise Invalid("Copy outside basis")
      }
      out.write_bytes(basis[offset:offset + length])
    }
    size += length
  }
  raise Invalid("Missing delta end")
}
