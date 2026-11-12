///|
/// Keep the signature/index in memory, but drain target and delta batches.
async fn delta_file(
  signature_path : String,
  target_path : String,
  output_path : String,
  input_limit : Int32,
  output_limit : Int32,
  basis_size : Int32,
  checks : Int32,
  chunk_size : Int32,
) -> Json {
  guard chunk_size >= 1 && chunk_size <= 65536 else {
    raise Usage("Chunk size must be 1..65536")
  }
  let signature = @rdiff.parse_signature(
    read_regular(signature_path, input_limit),
  )
  guard @fs.kind(target_path) is @fs.Regular else {
    raise Usage("Target must be a regular file")
  }
  let target = @fs.open(target_path, mode=ReadOnly)
  defer target.close()
  guard target.kind() is @fs.Regular else {
    raise Usage("Target is no longer regular")
  }
  let size = target.size()
  guard size >= 0L && size <= input_limit.to_int64() else {
    raise Usage("Target byte limit exceeded")
  }
  let mut written = 0
  // Preflight generated output budget before creating a result file.
  for pass in 0..<2 {
    let encoder = @rdiff.DeltaEncoder::new(
      signature,
      basis_size~,
      max_candidate_checks=checks,
      max_delta_size=output_limit,
      max_target_size=input_limit,
    )
    let output = if pass == 1 {
      Some(@fs.create(output_path, allow_existing=false, sync=NoSync))
    } else {
      None
    }
    defer (if output is Some(file) { file.close() })
    let mut position = 0L
    while position < size {
      let remaining = size - position
      let n = if remaining < chunk_size.to_int64() {
        remaining.to_int()
      } else {
        chunk_size
      }
      let batch = encoder.push(target.read_exactly_at(n, position~))
      if output is Some(file) {
        file.write(batch)
        written += batch.length()
      }
      position += n.to_int64()
    }
    let last_batch = encoder.finish()
    if output is Some(file) {
      file.write(last_batch)
      written += last_batch.length()
    }
    guard target.size() == size else {
      raise Usage("Target size changed during delta generation")
    }
    if output is Some(file) {
      file.sync(only_data=false)
    }
  }
  (
    {
      "command": "delta",
      "output_bytes": written,
      "incremental": true,
      "chunk_size": chunk_size,
    } : Json)
}
