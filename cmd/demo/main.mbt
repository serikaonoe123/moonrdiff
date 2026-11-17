///|
extern "C" fn exit_status(code : Int32) -> Unit = "exit"

///|
/// Invoke the actual file CLI; never import its private implementation.
async fn invoke(executable : String, arguments : Array[String]) -> Json {
  let (code, output, errors) = @process.collect_output(executable, arguments[:])
  guard code == 0 && errors.text().is_empty() else {
    fail("Demo command failed (exit \{code}): \{errors.text()}")
  }
  @json.parse(output.text())
}

///|
async fn run_demo(arguments : Array[String]) -> Unit {
  let profile = match arguments {
    [_] => "debug"
    [_, "--profile", "debug"] => "debug"
    [_, "--profile", "release"] => "release"
    _ =>
      fail(
        "Usage: demo [--profile debug|release]; run from the repository root",
      )
  }
  let root = @env.current_dir().unwrap()
  let executable = root +
    "/_build/native/" +
    profile +
    "/build/cmd/moonrdiff/moonrdiff.exe"
  guard @fs.exists(executable) else {
    fail("Build cmd/moonrdiff for the selected profile first")
  }
  if !@fs.exists("results") {
    @fs.mkdir("results")
  }
  let directory = root + "/results/demo-moonbit-" + @async.now().to_string()
  @fs.mkdir(directory)
  let input = @buffer.Buffer()
  for i in 0..<256 {
    let padding = if i < 10 { "000" } else if i < 100 { "00" } else { "0" }
    input.write_bytes(
      @utf8.encode("row \{padding}\{i}: example resource content\n"),
    )
  }
  let old = input.to_bytes()
  let updated = @buffer.Buffer()
  updated.write_bytes(b"New version header\n")
  updated.write_bytes(old[:4096])
  updated.write_bytes(b"An inserted record\n")
  updated.write_bytes(old[4096:])
  let new = updated.to_bytes()
  let basis = directory + "/old.bin"
  let target = directory + "/new.bin"
  let signature = directory + "/old.sig"
  let delta = directory + "/update.delta"
  let manifest = directory + "/binding.json"
  let restored = directory + "/restored.bin"
  @fs.write_file(basis, old, create_mode=CreateNew)
  @fs.write_file(target, new, create_mode=CreateNew)
  let commands = [
    ["signature", basis, signature, "--block-size", "128"],
    [
      "delta",
      signature,
      target,
      delta,
      "--basis-size",
      old.length().to_string(),
    ],
    ["manifest", basis, target, delta, manifest],
    ["patch", basis, delta, restored, "--manifest", manifest],
    ["verify", target, restored],
  ]
  let records : Array[Json] = []
  for command in commands {
    records.push(invoke(executable, command))
  }
  let result = @fs.open(restored, mode=ReadOnly)
  defer result.close()
  guard result.size() == new.length().to_int64() &&
    result.read_exactly_at(new.length(), position=0L) == new else {
    fail("Restored bytes differ from target; keep demonstration files")
  }
  let sig_file = @fs.open(signature, mode=ReadOnly)
  defer sig_file.close()
  let delta_file = @fs.open(delta, mode=ReadOnly)
  defer delta_file.close()
  let manifest_file = @fs.open(manifest, mode=ReadOnly)
  defer manifest_file.close()
  let sig_size = sig_file.size().to_int()
  let delta_size = delta_file.size().to_int()
  let manifest_size = manifest_file.size().to_int()
  let report : Json = {
    "basis_bytes": old.length(),
    "target_bytes": new.length(),
    "signature_bytes": sig_size,
    "delta_bytes": delta_size,
    "manifest_bytes": manifest_size,
    "first_exchange_bytes": sig_size + delta_size + manifest_size,
    "matched": true,
    "profile": profile,
    "directory": directory,
    "commands": records,
  }
  let text = report.stringify(indent=2) + "\n"
  @fs.write_file(
    directory + "/report.json",
    @utf8.encode(text),
    create_mode=CreateNew,
  )
  @stdio.stdout.write(text)
}

///|
async fn main {
  run_demo(@env.args()) catch {
    error => {
      @stdio.stderr.write(
        "Demo failed: \{error}\nKeep files already generated.\n",
      )
      exit_status(2)
    }
  }
}
