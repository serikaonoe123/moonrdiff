///|
/// Read and write bounded chunks, without retaining the whole basis/signature.
async fn signature_file(
  input_path : String,
  output_path : String,
  input_limit : Int32,
  output_limit : Int32,
  block_size : Int32,
  strong_length : Int32,
  chunk_size : Int32,
) -> Unit {
  guard chunk_size >= 1 && chunk_size <= 65536 else {
    raise Usage("Chunk size must be 1..65536")
  }
  let encoder = @rdiff.SignatureEncoder::new(
    block_size~,
    strong_length~,
    max_output=output_limit,
  )
  guard @fs.kind(input_path) is @fs.Regular else {
    raise Usage("Input must be a regular file")
  }
  let source = @fs.open(input_path, mode=ReadOnly)
  defer source.close()
  guard source.kind() is @fs.Regular else {
    raise Usage("Input is no longer a regular file")
  }
  let size = source.size()
  guard size >= 0L && size <= input_limit.to_int64() else {
    raise Usage("Input byte limit exceeded")
  }
  let block_count = size / block_size.to_int64() +
    (if size % block_size.to_int64() == 0L { 0L } else { 1L })
  guard block_count <= 1000000L &&
    12L + block_count * (4 + strong_length).to_int64() <=
    output_limit.to_int64() else {
    raise Usage("Signature output or block limit exceeded")
  }
  // Validate known size and configuration before exclusive output creation.
  let output = @fs.create(output_path, allow_existing=false, sync=NoSync)
  defer output.close()
  output.write(encoder.push(b""))
  let mut position = 0L
  while position < size {
    let remaining = size - position
    let n = if remaining < chunk_size.to_int64() {
      remaining.to_int()
    } else {
      chunk_size
    }
    let bytes = source.read_exactly_at(n, position~)
    output.write(encoder.push(bytes))
    position += n.to_int64()
  }
  output.write(encoder.finish())
  guard source.size() == size else {
    raise Usage("Input size changed while reading")
  }
  output.sync(only_data=false)
  @stdio.stdout.write(
    (
      {
        "command": "signature",
        "basis_size": size.to_int(),
        "signature_bytes": encoder.output_bytes(),
        "incremental": true,
        "chunk_size": chunk_size,
      } : Json).stringify() +
    "\n",
  )
}
