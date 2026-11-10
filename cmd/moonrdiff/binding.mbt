///|
struct FileIdentity {
  size : Int32
  hash : String
} derive(@json.ToJson, @json.FromJson)

///|
struct Binding {
  schema_version : Int32
  algorithm : String
  basis : FileIdentity
  target : FileIdentity
  delta : FileIdentity
} derive(@json.ToJson, @json.FromJson)

///|
fn hex_digest(bytes : Bytes) -> String {
  let digits = "0123456789abcdef".to_array()
  let out = StringBuilder()
  for byte in bytes {
    let n = byte.to_int()
    out.write_char(digits[n / 16])
    out.write_char(digits[n % 16])
  }
  out.to_string()
}

///|
fn validate_identity(identity : FileIdentity) -> Unit raise CliError {
  guard identity.size >= 0 && identity.hash.length() == 64 else {
    raise Usage("Invalid manifest identity")
  }
  for c in identity.hash.to_array() {
    guard (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') else {
      raise Usage("Invalid manifest digest")
    }
  }
}

///|
fn exact_keys(value : Json, keys : Array[String]) -> Unit raise CliError {
  guard value is Object(fields) && fields.length() == keys.length() else {
    raise Usage("Invalid manifest object")
  }
  for key in keys {
    guard fields.contains(key) else { raise Usage("Invalid manifest fields") }
  }
}

///|
async fn read_binding(path : String) -> Binding {
  let data = @json.parse(
    @utf8.decode(read_regular(path, 16384)),
    reject_duplicate_keys=true,
  )
  exact_keys(data, ["schema_version", "algorithm", "basis", "target", "delta"])
  guard data is Object(fields) else { raise Usage("Invalid manifest root") }
  for key in ["basis", "target", "delta"] {
    exact_keys(fields[key], ["size", "hash"])
  }
  let binding : Binding = @json.from_json(data)
  guard binding.schema_version == 1 && binding.algorithm == "blake2b-256" else {
    raise Usage("Unsupported manifest version or algorithm")
  }
  for identity in [binding.basis, binding.target, binding.delta] {
    validate_identity(identity)
  }
  binding
}

///|
async fn digest_handle(file : @fs.File, size : Int64) -> String {
  let hash = @crypto.Blake2b256::new()
  let mut position = 0L
  while position < size {
    let left = size - position
    let n = if left < 65536L { left.to_int() } else { 65536 }
    hash.push(file.read_exactly_at(n, position~))
    position += n.to_int64()
  }
  guard file.size() == size else {
    raise Usage("Input size changed while hashing")
  }
  hex_digest(hash.finish())
}

///|
async fn identify(path : String, limit : Int32) -> FileIdentity {
  guard @fs.kind(path) is @fs.Regular else {
    raise Usage("Manifest input must be regular")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  guard file.kind() is @fs.Regular else {
    raise Usage("Manifest input is no longer regular")
  }
  let size = file.size()
  guard size >= 0L && size <= limit.to_int64() else {
    raise Usage("Manifest input byte limit exceeded")
  }
  { size: size.to_int(), hash: digest_handle(file, size), }
}

///|
/// This records associations; bound patch preflight validates actual result.
async fn manifest_file(
  basis : String,
  target : String,
  delta : String,
  output : String,
  limit : Int32,
  output_limit : Int32,
) -> Unit {
  let binding = Binding::{
    schema_version: 1,
    algorithm: "blake2b-256",
    basis: identify(basis, limit),
    target: identify(target, limit),
    delta: identify(delta, limit),
  }
  let data = @utf8.encode(
    @json.ToJson::to_json(binding).stringify(indent=2) + "\n",
  )
  guard data.length() <= output_limit else {
    raise Usage("Manifest output byte limit exceeded")
  }
  let file = @fs.create(output, allow_existing=false, sync=NoSync)
  defer file.close()
  file.write(data)
  file.sync(only_data=false)
  @stdio.stdout.write("{\"command\":\"manifest\",\"schema_version\":1}\n")
}
