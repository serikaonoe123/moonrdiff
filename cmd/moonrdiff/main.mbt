///|
extern "C" fn exit_status(code : Int32) -> Unit = "exit"

///|
suberror CliError {
  Usage(String)
}

///|
fn number(value : String) -> Int32 raise CliError {
  guard !value.is_empty() else {
    raise Usage("Expected a nonnegative decimal integer")
  }
  let mut n = 0
  for c in value.to_array() {
    let d = c.to_int() - 48
    guard d >= 0 && d <= 9 && n <= (2147483647 - d) / 10 else {
      raise Usage("Expected a nonnegative Int32 decimal integer")
    }
    n = n * 10 + d
  }
  n
}

///|
async fn read_regular(path : String, limit : Int32) -> Bytes {
  guard @fs.kind(path) is @fs.Regular else {
    raise Usage("Input must be a regular file: " + path)
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  guard file.kind() is @fs.Regular else {
    raise Usage("Input is no longer a regular file")
  }
  let size = file.size()
  guard size >= 0L && size <= limit.to_int64() else {
    raise Usage("Input byte limit exceeded: " + path)
  }
  let data = file.read_exactly_at(size.to_int(), position=0L)
  guard file.size() == size else {
    raise Usage("Input size changed while reading: " + path)
  }
  data
}

///|
fn help() -> String {
  "MoonRdiff (incremental signature/delta/patch)\n" +
  "  signature BASIS SIGNATURE [--block-size N] [--strong-length N] [--chunk-size N]\n" +
  "  delta SIGNATURE TARGET DELTA --basis-size N [--max-checks N]\n" +
  "  patch BASIS DELTA OUTPUT [--chunk-size N] [--max-instructions N]\n" +
  "  verify EXPECTED ACTUAL\n  manifest BASIS TARGET DELTA MANIFEST\n  patch may add --manifest MANIFEST for file binding verification\n" +
  "Options: --max-input N and --max-output N (bytes, default 67108864).\n" +
  "Outputs must be new files. Exit: 0 success, 1 verify mismatch, 2 error.\n"
}

///|
async fn execute(args : Array[String]) -> Int32 {
  if args.length() == 2 && args[1] == "--help" {
    @stdio.stdout.write(help())
    return 0
  }
  guard args.length() >= 2 else { raise Usage(help()) }
  let command = args[1]
  let required = match command {
    "signature" | "verify" => 2
    "manifest" => 4
    "delta" | "patch" => 3
    _ => raise Usage("Unknown command\n" + help())
  }
  guard args.length() >= required + 2 else {
    raise Usage("Missing file arguments\n" + help())
  }
  let options : Map[String, Int32] = Map([])
  let mut manifest_path : String? = None
  let mut offset = required + 2
  while offset < args.length() {
    guard offset + 1 < args.length() else {
      raise Usage("Missing option value")
    }
    let name = args[offset]
    if name == "--manifest" && command == "patch" {
      guard manifest_path is None else {
        raise Usage("Repeated manifest option")
      }
      manifest_path = Some(args[offset + 1])
      offset += 2
      continue
    }
    let allowed = name == "--max-input" ||
      (command != "verify" && name == "--max-output") ||
      (
        command == "signature" &&
        (
          name == "--block-size" ||
          name == "--strong-length" ||
          name == "--chunk-size"
        )
      ) ||
      (
        command == "patch" &&
        (name == "--chunk-size" || name == "--max-instructions")
      ) ||
      (
        command == "delta" &&
        (
          name == "--basis-size" ||
          name == "--max-checks" ||
          name == "--chunk-size"
        )
      )
    guard allowed && !options.contains(name) else {
      raise Usage("Unknown or repeated option: " + name)
    }
    options[name] = number(args[offset + 1])
    offset += 2
  }
  let input_limit = options.get("--max-input").unwrap_or(67108864)
  let output_limit = options.get("--max-output").unwrap_or(67108864)
  // Validate command options before opening any input or output file.
  if command == "delta" && options.get("--basis-size") is None {
    raise Usage("delta requires --basis-size")
  }
  if command == "manifest" {
    manifest_file(args[2], args[3], args[4], args[5], input_limit, output_limit)
    return 0
  }
  if command == "signature" {
    signature_file(
      args[2],
      args[3],
      input_limit,
      output_limit,
      options.get("--block-size").unwrap_or(2048),
      options.get("--strong-length").unwrap_or(32),
      options.get("--chunk-size").unwrap_or(65536),
    )
    return 0
  }
  if command == "patch" {
    patch_file(
      args[2],
      args[3],
      args[4],
      input_limit,
      output_limit,
      options.get("--chunk-size").unwrap_or(65536),
      options.get("--max-instructions").unwrap_or(1000000),
      match manifest_path {
        Some(path) => Some(read_binding(path))
        None => None
      },
    )
    return 0
  }
  if command == "delta" {
    delta_file(
      args[2],
      args[3],
      args[4],
      input_limit,
      output_limit,
      options["--basis-size"],
      options.get("--max-checks").unwrap_or(1000000),
      options.get("--chunk-size").unwrap_or(65536),
    )
    return 0
  }
  let first = read_regular(args[2], input_limit)
  let second = read_regular(args[3], input_limit)
  if command == "verify" {
    let matched = first == second
    @stdio.stdout.write(
      (
        {
          "command": "verify",
          "matched": matched,
          "expected_bytes": first.length(),
          "actual_bytes": second.length(),
        } : Json).stringify() +
      "\n",
    )
    return if matched { 0 } else { 1 }
  }
  0
}

///|
/// Release builds need explicit payload formatting for these public diagnostics.
fn diagnostic(error : Error) -> String {
  match error {
    Usage(message) => message
    @rdiff.Invalid(message) => message
    _ => error.to_string()
  }
}

///|
async fn main {
  let code = execute(@env.args()) catch {
    error => {
      @stdio.stderr.write(
        "moonrdiff: \{diagnostic(error)}\nNo existing output was overwritten. A partial new file may remain if writing failed.\n",
      )
      2
    }
  }
  exit_status(code)
}
