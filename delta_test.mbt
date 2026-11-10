///|
test "copy addresses basis and literal appends bytes" {
  let delta = @moonrdiff.encode([
    Copy(offset=6, length=5),
    Literal(b"!"),
    Copy(offset=0, length=5),
  ])
  assert_eq(
    @moonrdiff.patch(b"hello world", delta, max_output=11),
    b"world!hello",
  )
}

///|
test "literal encoding switches at 64 bytes and preserves binary data" {
  for length in [0, 1, 64, 65, 255, 256, 1024] {
    let data = @buffer.Buffer()
    for i in 0..<length {
      data.write_byte((i % 256).to_byte())
    }
    let bytes = data.to_bytes()
    let encoded = @moonrdiff.encode([Literal(bytes)])
    assert_eq(@moonrdiff.patch(b"", encoded, max_output=length), bytes)
    if length > 64 {
      assert_eq(encoded[4], b'\x43')
    }
  }
}

///|
test "all literal and copy parameter widths" {
  for a in 0..<4 {
    for b in 0..<4 {
      let out = @buffer.Buffer()
      out.write_bytes(b"rs\x02\x36")
      out.write_byte((69 + a * 4 + b).to_byte())
      for _ in 0..<((1 << a) - 1) {
        out.write_byte(b'\x00')
      }
      out.write_byte(b'\x01')
      for _ in 0..<((1 << b) - 1) {
        out.write_byte(b'\x00')
      }
      out.write_byte(b'\x02')
      out.write_byte(b'\x00')
      assert_eq(@moonrdiff.patch(b"abcd", out.to_bytes(), max_output=2), b"bc")
    }
    let out = @buffer.Buffer()
    out.write_bytes(b"rs\x02\x36")
    out.write_byte((65 + a).to_byte())
    for _ in 0..<((1 << a) - 1) {
      out.write_byte(b'\x00')
    }
    out.write_byte(b'\x01')
    out.write_bytes(b"z\x00")
    assert_eq(@moonrdiff.patch(b"", out.to_bytes(), max_output=1), b"z")
  }
}

///|
test "every proper truncation fails" {
  let valid = @moonrdiff.encode([Literal(b"abc"), Copy(offset=0, length=3)])
  for length in 0..<valid.length() {
    let result = Ok(
      @moonrdiff.patch(b"old", valid[0:length].to_owned(), max_output=6),
    ) catch {
      e => Err(e)
    }
    match result {
      Ok(_) => fail("Truncation accepted at \{length}")
      Err(_) => ()
    }
  }
}

///|
test "budget range overflow reserved and trailing errors" {
  for
    delta in [
      b"rs\x02\x36\x55\x00", b"rs\x02\x36\x00x", b"rs\x02\x36\x45\xff\x01\x00", b"rs\x02\x36\x44\x80\x00\x00\x00\x00\x00\x00\x00",
      b"rs\x02\x36\x02ab\x00",
    ] {
    match
      (Ok(@moonrdiff.patch(b"x", delta, max_output=1)) catch { e => Err(e) }) {
      Ok(_) => fail("Invalid input accepted")
      Err(_) => ()
    }
  }
  assert_eq(@moonrdiff.patch(b"", @moonrdiff.encode([]), max_output=0), b"")
}
