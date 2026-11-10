///|
/// Validate in one bounded pass, then replay into an exclusive new output.
async fn patch_file(
  basis_path : String,
  delta_path : String,
  output_path : String,
  input_limit : Int32,
  output_limit : Int32,
  chunk_size : Int32,
  max_instructions : Int32,
) -> Unit {
  guard chunk_size >= 1 && chunk_size <= 65536 else {
    raise Usage("Chunk size must be 1..65536")
  }
  guard @fs.kind(basis_path) is @fs.Regular &&
    @fs.kind(delta_path) is @fs.Regular else {
    raise Usage("Patch inputs must be regular files")
  }
  let basis = @fs.open(basis_path, mode=ReadOnly)
  defer basis.close()
  let delta = @fs.open(delta_path, mode=ReadOnly)
  defer delta.close()
  guard basis.kind() is @fs.Regular && delta.kind() is @fs.Regular else {
    raise Usage("Input is no longer regular")
  }
  let basis_size = basis.size()
  let delta_size = delta.size()
  guard basis_size >= 0L &&
    basis_size <= input_limit.to_int64() &&
    delta_size >= 0L &&
    delta_size <= input_limit.to_int64() else {
    raise Usage("Patch input byte limit exceeded")
  }
  let mut written = 0
  for pass in 0..<2 {
    let decoder = @rdiff.PatchDecoder::new(
      basis_size=basis_size.to_int(),
      max_output=output_limit,
      max_instructions~,
    )
    let output = if pass == 1 {
      Some(@fs.create(output_path, allow_existing=false, sync=NoSync))
    } else {
      None
    }
    defer (if output is Some(file) { file.close() })
    let mut position = 0L
    while position < delta_size {
      let remaining = delta_size - position
      let n = if remaining < chunk_size.to_int64() {
        remaining.to_int()
      } else {
        chunk_size
      }
      let bytes = delta.read_exactly_at(n, position~)
      let parts = decoder.push(bytes)
      if output is Some(file) {
        for part in parts {
          match part {
            @rdiff.Literal(data) => {
              file.write(data)
              written += data.length()
            }
            @rdiff.Copy(offset~, length~) => {
              let mut copied = 0
              while copied < length {
                let left = length - copied
                let amount = if left < chunk_size { left } else { chunk_size }
                let data = basis.read_exactly_at(
                  amount,
                  position=(offset + copied).to_int64(),
                )
                file.write(data)
                copied += amount
                written += amount
              }
            }
          }
        }
      }
      position += n.to_int64()
    }
    decoder.finish()
    guard basis.size() == basis_size && delta.size() == delta_size else {
      raise Usage("Input size changed while patching")
    }
    if output is Some(file) {
      file.sync(only_data=false)
    }
  }
  @stdio.stdout.write(
    (
      {
        "command": "patch",
        "output_bytes": written,
        "incremental": true,
        "chunk_size": chunk_size,
      } : Json).stringify() +
    "\n",
  )
}
