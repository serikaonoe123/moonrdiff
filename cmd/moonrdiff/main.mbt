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
/// CreateNew is an exclusive OS operation; existing files are never truncated.
async fn write_new(path : String, data : Bytes) -> Unit {
  let file = @fs.create(path, allow_existing=false, sync=Full)
  defer file.close()
  file.write(data)
  file.sync(only_data=false)
}

///|
fn help() -> String {
  "MoonRdiff (in-memory file CLI)\n" +
  "  signature BASIS SIGNATURE [--block-size N] [--strong-length N]\n" +
  "  delta SIGNATURE TARGET DELTA --basis-size N [--max-checks N]\n" +
  "  patch BASIS DELTA OUTPUT\n" +
  "  verify EXPECTED ACTUAL\n" +
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
    "delta" | "patch" => 3
    _ => raise Usage("Unknown command\n" + help())
  }
  guard args.length() >= required + 2 else {
    raise Usage("Missing file arguments\n" + help())
  }
  let options : Map[String, Int32] = Map([])
  let mut offset = required + 2
  while offset < args.length() {
    guard offset + 1 < args.length() else {
      raise Usage("Missing option value")
    }
    let name = args[offset]
    let allowed = name == "--max-input" ||
      (command != "verify" && name == "--max-output") ||
      (
        command == "signature" &&
        (name == "--block-size" || name == "--strong-length")
      ) ||
      (command == "delta" && (name == "--basis-size" || name == "--max-checks"))
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
  let first = read_regular(args[2], input_limit)
  if command == "signature" {
    let result = @rdiff.signature(
      first,
      block_size=options.get("--block-size").unwrap_or(2048),
      strong_length=options.get("--strong-length").unwrap_or(32),
    )
    guard result.length() <= output_limit else {
      raise Usage("Output byte limit exceeded")
    }
    write_new(args[3], result)
    @stdio.stdout.write(
      (
        {
          "command": "signature",
          "basis_size": first.length(),
          "signature_bytes": result.length(),
        } : Json).stringify() +
      "\n",
    )
    return 0
  }
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
  let result = if command == "delta" {
    @rdiff.delta(
      @rdiff.parse_signature(first),
      second,
      basis_size=options["--basis-size"],
      max_candidate_checks=options.get("--max-checks").unwrap_or(1000000),
      max_delta_size=output_limit,
    )
  } else {
    @rdiff.patch(first, second, max_output=output_limit)
  }
  write_new(args[4], result)
  @stdio.stdout.write(
    ({ "command": command, "output_bytes": result.length() } : Json).stringify() +
    "\n",
  )
  0
}

///|
async fn main {
  let code = execute(@env.args()) catch {
    error => {
      @stdio.stderr.write(
        "moonrdiff: \{error}\nNo existing output was overwritten. A partial new file may remain if writing failed.\n",
      )
      2
    }
  }
  exit_status(code)
}
