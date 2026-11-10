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

///|
/// Independent hashlib vectors exercise reused compression workspaces and
/// output-size parameterization, including full final blocks and many blocks.
test "optimized one-shot BLAKE2b matches hashlib digest sizes and block boundaries" {
  for
    (size, output_size, expected) in [
      (0, 1, b"\x2e"),
      (
        0, 16, b"\xca\xe6\x69\x41\xd9\xef\xbd\x40\x4e\x4d\x88\x75\x8e\xa6\x76\x70",
      ),
      (
        0, 32, b"\x0e\x57\x51\xc0\x26\xe5\x43\xb2\xe8\xab\x2e\xb0\x60\x99\xda\xa1\xd1\xe5\xdf\x47\x77\x8f\x77\x87\xfa\xab\x45\xcd\xf1\x2f\xe3\xa8",
      ),
      (
        0, 64, b"\x78\x6a\x02\xf7\x42\x01\x59\x03\xc6\xc6\xfd\x85\x25\x52\xd2\x72\x91\x2f\x47\x40\xe1\x58\x47\x61\x8a\x86\xe2\x17\xf7\x1f\x54\x19\xd2\x5e\x10\x31\xaf\xee\x58\x53\x13\x89\x64\x44\x93\x4e\xb0\x4b\x90\x3a\x68\x5b\x14\x48\xb7\x55\xd5\x6f\x70\x1a\xfe\x9b\xe2\xce",
      ),
      (127, 1, b"\x47"),
      (
        127, 16, b"\xf6\x8f\xc0\x3a\x10\xe1\x2d\x4b\x9d\xa8\xc6\x98\x35\x19\x45\xf8",
      ),
      (
        127, 32, b"\xe8\x32\x33\xa7\x2f\x93\xb5\x2d\x1e\x75\x47\x5d\xf3\xee\xad\xf1\x76\x23\x0c\x09\x0a\x6d\x20\xa8\x3b\xd8\x78\x02\x49\x6e\x32\xe2",
      ),
      (
        127, 64, b"\x2a\x54\x1f\xd5\x07\x91\x23\xe3\x69\x44\x5b\xa0\xd5\x10\x94\xda\x81\x98\x5d\xa0\x8c\x6c\xfe\xb4\xb3\xa1\x62\x2d\x35\x85\xb9\x58\x07\xd9\x26\x95\x11\x53\xae\x54\x00\xa0\xa2\xf9\xe2\x7b\xc5\x65\x06\x67\xcd\x29\xa1\xf1\x08\xb0\xa3\xa4\x78\xdd\x07\x65\xc5\x8b",
      ),
      (128, 1, b"\xf6"),
      (
        128, 16, b"\x12\xf6\x9b\x53\xc8\xa7\x07\xc3\x0e\x2d\x28\xb0\xc1\x27\xd6\x7f",
      ),
      (
        128, 32, b"\xb0\x07\xed\x92\xd5\x85\x55\x4b\x8d\xab\x53\x01\xcd\x34\xf8\x60\x66\x89\x87\x38\x39\xe4\x16\x7c\x5b\xfb\xe1\x8b\x1d\x3f\x73\xf1",
      ),
      (
        128, 64, b"\xb1\x94\x82\x7b\xd9\x46\x1c\x00\xb0\x69\x46\xdb\x7a\x92\x3e\x02\xfc\x82\x67\x29\x9d\x87\xbc\x45\x2b\x9b\x60\x91\x1d\x9f\xd6\xc0\xae\x23\x9d\x9d\x7c\xeb\xc5\x4d\x29\x26\x41\x46\x9b\xd7\xa0\x75\x46\xcc\x88\x70\x7b\x78\xaa\xb4\x31\xa4\x51\x3a\x69\x37\x91\xb2",
      ),
      (129, 1, b"\x77"),
      (
        129, 16, b"\xf9\x2f\xe4\x6e\x12\x8d\xfb\xce\x21\xb8\x9f\xad\x88\x55\xdc\xfb",
      ),
      (
        129, 32, b"\x61\x25\xaf\xec\x0a\xff\xd5\xaa\xcf\xfe\x40\xe5\x6a\x1f\x0c\x3e\x15\x16\x33\x76\xe8\x75\xc1\x3a\x61\x4f\x6c\x2a\x47\xbc\x8c\x0a",
      ),
      (
        129, 64, b"\x9f\x38\xd9\x16\x90\xd2\x65\xc3\x37\x8c\x66\xba\xf0\xaa\xbb\x6f\x9e\x68\x32\x3e\x18\xf2\xb4\x3b\x7d\x1d\xd8\xd8\xc3\x01\x41\x82\x67\x67\xca\xc5\x1e\x3a\x8e\x86\xf6\xa8\x20\x10\x73\x5f\x60\x24\x31\x39\xaf\x18\xd2\xb7\x92\xbb\x59\xb7\xbc\x1d\xe9\xb3\xbb\x54",
      ),
      (256, 1, b"\xa6"),
      (
        256, 16, b"\x5d\x5e\x97\xf2\xae\x9a\x18\x89\xd8\xb1\x56\xa7\xd6\xe8\xc9\x3c",
      ),
      (
        256, 32, b"\xb7\x9a\xe2\x82\x9b\x3a\xd9\xe8\xf4\x91\xc8\x0f\x30\xd3\x57\xb1\x16\xce\x97\xc7\xdd\xf6\xf1\x1b\xbe\x18\xb1\xb5\x1b\x7e\x49\xc1",
      ),
      (
        256, 64, b"\x9a\xb0\x00\x3b\x0f\x7e\xd4\xed\x81\x03\x0d\xeb\x25\x58\xaa\x2e\x6e\xaf\xc9\xb5\xae\x9c\xa5\x0f\xc8\xcc\xf1\x37\xf6\x84\xda\x78\xb0\x38\x18\x54\x56\xe7\x65\x0f\x07\x2f\x41\xff\xb8\x74\x54\x52\x56\x6a\xef\xdf\xf5\x45\x4a\xf1\x26\xb8\xb7\x32\xfd\x37\x1a\xc9",
      ),
      (4096, 1, b"\x3e"),
      (
        4096, 16, b"\x6e\x7c\x9c\xbd\xc3\x5d\xa9\xcf\xbd\x53\x70\x60\xf7\x86\x02\x5e",
      ),
      (
        4096, 32, b"\xef\xf5\x40\x2d\x12\x33\xf8\x84\x25\xbf\xb3\x4f\x7a\x05\x53\xbd\x9e\x90\x88\x2d\xbb\xca\x5f\x76\x52\xe9\x6c\x10\xb9\xed\xe0\xdb",
      ),
      (
        4096, 64, b"\x7a\xbc\x70\xdb\xf8\x8c\xe2\x48\x4c\x9b\xf6\xfd\x00\xd5\x08\x74\x35\xb2\x0d\xed\x48\x55\x91\xb2\x0c\xbf\xae\xf1\x81\x06\xde\x29\xd9\x07\x96\x72\x59\x30\x5d\x49\x0e\x10\x5b\xdb\x86\xac\x54\xfc\x88\x6e\x32\xa9\xf3\xf8\x74\xe4\x15\x66\xf1\x5a\x6b\x5c\x57\x1c",
      ),
    ] {
    let input = @buffer.Buffer()
    for i in 0..<size {
      input.write_byte(((i * 73 + 255) % 256).to_byte())
    }
    assert_eq(@mooncry_blake2.blake2b(input.to_bytes(), output_size), expected)
  }
}
