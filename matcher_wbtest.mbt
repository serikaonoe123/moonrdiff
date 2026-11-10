///|
/// Compare each rolling update with a freshly evaluated polynomial.
test "rolling polynomial equals recomputation" {
  let buffer = @buffer.Buffer()
  for i in 0..<512 {
    buffer.write_byte(((i * 73 + 255) % 256).to_byte())
  }
  let input = buffer.to_bytes()
  for length in [1, 2, 7, 32, 127, 128, 255] {
    let mut checksum = rk_checksum(input[0:length])
    for position in 0..<(input.length() - length) {
      checksum = rk_slide(
        checksum,
        input[position],
        input[position + length],
        rk_power(length),
      )
      assert_eq(
        checksum,
        rk_checksum(input[position + 1:position + 1 + length]),
      )
    }
  }
}
