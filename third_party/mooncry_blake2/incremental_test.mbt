///|
/// Independent Python hashlib BLAKE2b-256 vectors, including exact blocks.
test "incremental BLAKE2b256 vectors partitions and lifecycle" {
  {
    let input = @buffer.Buffer()
    for i in 0..<0 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\x0e\x57\x51\xc0\x26\xe5\x43\xb2\xe8\xab\x2e\xb0\x60\x99\xda\xa1\xd1\xe5\xdf\x47\x77\x8f\x77\x87\xfa\xab\x45\xcd\xf1\x2f\xe3\xa8",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<1 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xac\x4e\x40\x76\xa8\x83\x93\x72\x82\xf1\x37\x7e\xf5\xca\xcb\x8e\xdd\x00\xe3\xc7\x96\x29\xe4\x35\x32\x46\x4e\xb3\xbe\x27\x73\x67",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<127 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xe8\x32\x33\xa7\x2f\x93\xb5\x2d\x1e\x75\x47\x5d\xf3\xee\xad\xf1\x76\x23\x0c\x09\x0a\x6d\x20\xa8\x3b\xd8\x78\x02\x49\x6e\x32\xe2",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<128 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xb0\x07\xed\x92\xd5\x85\x55\x4b\x8d\xab\x53\x01\xcd\x34\xf8\x60\x66\x89\x87\x38\x39\xe4\x16\x7c\x5b\xfb\xe1\x8b\x1d\x3f\x73\xf1",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<129 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\x61\x25\xaf\xec\x0a\xff\xd5\xaa\xcf\xfe\x40\xe5\x6a\x1f\x0c\x3e\x15\x16\x33\x76\xe8\x75\xc1\x3a\x61\x4f\x6c\x2a\x47\xbc\x8c\x0a",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<255 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xa7\x01\xc7\x35\xaf\x43\xe3\x55\xef\xe1\x5e\x49\x18\xae\x98\xd6\xd9\xb7\xd5\x76\x69\x48\x62\x0f\x11\x6a\x3b\x99\x11\x54\xe1\xf2",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<256 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xb7\x9a\xe2\x82\x9b\x3a\xd9\xe8\xf4\x91\xc8\x0f\x30\xd3\x57\xb1\x16\xce\x97\xc7\xdd\xf6\xf1\x1b\xbe\x18\xb1\xb5\x1b\x7e\x49\xc1",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<257 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\xf5\xc4\x84\xdb\xcc\x57\xca\x7a\x63\xf3\xd7\xe0\xf8\x3c\x66\x69\xfe\x2b\x52\x80\x74\x7a\x6e\x3d\x0a\xad\x9c\xe1\xd2\xf6\xdf\x8d",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<4097 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\x93\x46\x77\x4b\x8b\xb3\xa1\xd0\xe1\x18\x88\x24\x0c\x7d\xce\xb8\x2f\xb6\xf9\xcc\xb5\xc4\x14\xaf\x2c\x0c\x03\x7f\x80\x47\x94\x63",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  {
    let input = @buffer.Buffer()
    for i in 0..<65537 {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    let bytes = input.to_bytes()
    for chunk_size in [1, 7, 128, 65536] {
      let hash = @mooncry_blake2.Blake2b256::new()
      hash.push(b"")
      let mut pos = 0
      while pos < bytes.length() {
        let left = bytes.length() - pos
        let n = if chunk_size < left { chunk_size } else { left }
        hash.push(bytes[pos:pos + n])
        pos += n
      }
      assert_eq(
        hash.finish(),
        b"\x82\x44\xce\x74\x52\x0b\x9b\x43\xf9\x74\xa9\xd8\xee\x48\x37\x5c\x07\x99\xc5\xeb\x3a\xa5\xf0\xb0\xff\x3f\xf2\x2c\x0c\x64\xf0\x82",
      )
      assert_true(
        try {
          hash.push(b"x")
          false
        } catch {
          _ => true
        },
      )
      assert_true(
        try {
          ignore(hash.finish())
          false
        } catch {
          _ => true
        },
      )
    }
  }
  let bad = @mooncry_blake2.Blake2b256::new()
  assert_true(
    try {
      bad.push(Bytes::make(65537, b'x'))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(bad.finish())
      false
    } catch {
      _ => true
    },
  )
}
