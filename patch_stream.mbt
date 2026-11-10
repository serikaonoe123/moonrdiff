///| Incremental parser yielding literal fragments and basis COPY requests.

///|
/// Caller must consume each batch; this object does not read or retain basis bytes.
pub struct PatchDecoder {
  priv basis_size : Int32
  priv max_output : Int32
  priv max_instructions : Int32
  priv pending : Array[Byte]
  priv mut stage : Int32 // 0 magic, 1 opcode, 2 parameters, 3 literal, 4 end
  priv mut opcode : Int32
  priv mut needed : Int32
  priv mut remaining : Int32
  priv mut total : Int32
  priv mut instructions : Int32
  priv mut closed : Bool
  priv mut failed : Bool
}

///|
pub fn PatchDecoder::new(
  basis_size~ : Int32,
  max_output~ : Int32,
  max_instructions~ : Int32 = 1000000,
) -> PatchDecoder raise DeltaError {
  guard basis_size >= 0 && max_output >= 0 && max_instructions >= 0 else {
    raise Invalid("Invalid patch decoder configuration")
  }
  {
    basis_size,
    max_output,
    max_instructions,
    pending: [],
    stage: 0,
    opcode: 0,
    needed: 4,
    remaining: 0,
    total: 0,
    instructions: 0,
    closed: false,
    failed: false,
  }
}

///|
fn PatchDecoder::reserve(
  self : PatchDecoder,
  length : Int32,
) -> Unit raise DeltaError {
  guard length <= self.max_output - self.total else {
    raise Invalid("Output budget exceeded")
  }
  self.total += length
}

///|
fn PatchDecoder::literal(
  self : PatchDecoder,
  length : Int32,
) -> Unit raise DeltaError {
  self.reserve(length)
  self.remaining = length
  self.stage = if length == 0 { 1 } else { 3 }
}

///|
/// A failed batch may have advanced state; errors permanently poison this decoder.
pub fn PatchDecoder::push(
  self : PatchDecoder,
  chunk : BytesView,
) -> Array[Instruction] raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Patch decoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  guard chunk.length() <= 65536 else {
    raise Invalid("Patch push exceeds 64 KiB")
  }
  let output : Array[Instruction] = []
  let mut position = 0
  while position < chunk.length() {
    if self.stage == 4 {
      raise Invalid("Trailing data after end")
    }
    if self.stage == 3 {
      let available = chunk.length() - position
      let n = if available < self.remaining {
        available
      } else {
        self.remaining
      }
      output.push(Literal(chunk[position:position + n].to_owned()))
      position += n
      self.remaining -= n
      if self.remaining == 0 {
        self.stage = 1
      }
    } else if self.stage == 1 {
      let op = chunk[position].to_int()
      position += 1
      if op == 0 {
        self.stage = 4
        continue
      }
      guard self.instructions < self.max_instructions else {
        raise Invalid("Patch instruction budget exceeded")
      }
      self.instructions += 1
      if op <= 64 {
        self.literal(op)
      } else if op <= 84 {
        self.opcode = op
        self.needed = if op <= 68 {
          1 << (op - 65)
        } else {
          let code = op - 69
          (1 << (code / 4)) + (1 << (code % 4))
        }
        self.stage = 2
      } else {
        raise Invalid("Reserved delta instruction")
      }
    } else {
      self.pending.push(chunk[position])
      position += 1
      if self.pending.length() == self.needed {
        let data = Bytes::from_array(self.pending[:])
        self.pending.clear()
        if self.stage == 0 {
          guard data == b"rs\x02\x36" else {
            raise Invalid("Unsupported delta magic")
          }
          self.stage = 1
        } else {
          let cursor = Cursor::{ data, position: 0, }
          if self.opcode <= 68 {
            self.literal(cursor.integer(self.needed))
          } else {
            let code = self.opcode - 69
            let offset = cursor.integer(1 << (code / 4))
            let length = cursor.integer(1 << (code % 4))
            guard offset <= self.basis_size &&
              length <= self.basis_size - offset else {
              raise Invalid("Copy outside basis")
            }
            self.reserve(length)
            if length > 0 {
              output.push(Copy(offset~, length~))
            }
            self.stage = 1
          }
        }
      }
    }
  }
  output
}

///|
/// End of input is explicit; missing END or unfinished literal/header is an error.
pub fn PatchDecoder::finish(self : PatchDecoder) -> Unit raise DeltaError {
  guard !self.closed && !self.failed else {
    raise Invalid("Patch decoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  guard self.stage == 4 else { raise Invalid("Truncated patch or missing end") }
  self.closed = true
}
