///|
/// Test transport only: hex avoids any file I/O in the algorithm prototype.
fn unhex(value : String) -> Bytes {
  let out = @buffer.Buffer()
  let chars = value.to_array()
  for i = 0; i < chars.length(); i = i + 2 {
    let mut byte = 0
    for j in 0..<2 {
      let c = chars[i + j].to_int()
      byte = byte * 16 + (if c <= 57 { c - 48 } else { c - 97 + 10 })
    }
    out.write_byte(byte.to_byte())
  }
  out.to_bytes()
}

///|
fn hex(value : Bytes) -> String {
  let out = StringBuilder()
  let digits = "0123456789abcdef".to_array()
  for byte in value {
    let n = byte.to_int()
    out.write_char(digits[n / 16])
    out.write_char(digits[n % 16])
  }
  out.to_string()
}

///|
fn main {
  let args = @env.args()
  if args.length() == 3 && args[2] == "encode-fixture" {
    println(
      hex(
        @rdiff.encode([
          @rdiff.Copy(offset=6, length=5),
          @rdiff.Literal(b"!"),
          @rdiff.Copy(offset=0, length=5),
        ]) catch {
          _ => abort("Invalid probe delta")
        },
      ),
    )
  } else if args.length() == 6 && args[2] == "signature" {
    println(
      hex(
        @rdiff.signature(
          unhex(args[3]),
          block_size=unhex(args[4])[0].to_int(),
          strong_length=unhex(args[5])[0].to_int(),
        ) catch {
          _ => abort("Invalid signature configuration")
        },
      ),
    )
  } else if args.length() == 4 && args[2] == "signature-roundtrip" {
    let signature = @rdiff.parse_signature(unhex(args[3])) catch {
      _ => abort("Invalid signature input")
    }
    println(hex(signature.to_bytes()))
  } else if args.length() == 5 && args[2] == "patch" {
    println(
      hex(
        @rdiff.patch(unhex(args[3]), unhex(args[4]), max_output=1048576) catch {
          _ => abort("Invalid probe delta")
        },
      ),
    )
  } else {
    abort("Developer probe: encode-fixture | patch BASIS_HEX DELTA_HEX")
  }
}
