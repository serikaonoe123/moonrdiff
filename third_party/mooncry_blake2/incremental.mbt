// SPDX-License-Identifier: Apache-2.0
// MoonRdiff incremental adapter, 2026. Reuses the attributed compression core.

///|
pub suberror HashStateError {
  InvalidState
}

///|
/// Unkeyed, fixed BLAKE2b-256; bounded pushes and a 128-byte pending block.
pub struct Blake2b256 {
  priv h : Array[UInt64]
  priv pending : Array[Byte]
  priv mut used : Int32
  priv mut total : UInt64
  priv mut closed : Bool
}

///|
pub fn Blake2b256::new() -> Blake2b256 {
  let h = Array::make(8, 0UL)
  for i in 0..<8 {
    h[i] = blake2b_iv[i]
  }
  h[0] = h[0] ^ 0x01010020UL
  { h, pending: Array::make(128, b'\x00'), used: 0, total: 0UL, closed: false, }
}

///|
fn Blake2b256::compress(self : Blake2b256, last : Bool) -> Unit {
  for i in self.used..<128 {
    self.pending[i] = b'\x00'
  }
  let bytes = Bytes::from_array(self.pending[:])
  let words = Array::make(16, 0UL)
  for i in 0..<16 {
    words[i] = blake2b_read_lane(bytes, i * 8)
  }
  self.total += self.used.to_uint64()
  blake2b_compress(self.h, words, self.total, last)
  self.used = 0
}

///|
pub fn Blake2b256::push(
  self : Blake2b256,
  bytes : BytesView,
) -> Unit raise HashStateError {
  guard !self.closed else { raise InvalidState }
  if bytes.length() > 65536 ||
    self.total > 0xFFFFFFFFFFFFFFFFUL - (self.used + bytes.length()).to_uint64() {
    self.closed = true
    raise InvalidState
  }
  for byte in bytes {
    if self.used == 128 {
      self.compress(false)
    }
    self.pending[self.used] = byte
    self.used += 1
  }
}

///|
pub fn Blake2b256::finish(self : Blake2b256) -> Bytes raise HashStateError {
  guard !self.closed else { raise InvalidState }
  self.compress(true)
  self.closed = true
  let out = Array::make(32, b'\x00')
  for i in 0..<4 {
    let word = self.h[i].to_le_bytes()
    for j in 0..<8 {
      out[i * 8 + j] = word[j]
    }
  }
  Bytes::from_array(out[:])
}
