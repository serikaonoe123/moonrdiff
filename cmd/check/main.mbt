///|
extern "js" fn exit_status(code : Int32) -> Unit =
  #| code => process.exit(code)

///|
fn check(arguments : Array[String]) -> Int32 raise {
  let skip_links = match arguments {
    [_, _] => false
    [_, _, "--skip-links"] => true
    _ => fail("Usage: check [--skip-links]; run from repository root")
  }
  let commands : Array[Array[String]] = [
    ["moon", "version", "--all"],
    ["moon", "fmt", "--check"],
  ]
  for target in ["js", "native", "wasm-gc"] {
    for action in ["check", "test", "build"] {
      commands.push(["moon", action, "--target", target, "--deny-warn"])
    }
  }
  let cli = ["moon", "run", "cmd/cli-check", "--target", "native"]
  if skip_links {
    cli.push("--")
    cli.push("--skip-links")
  }
  commands.push(cli)
  commands.push(["moon", "info"])
  commands.push([
    "git", "diff", "--exit-code", "--", "pkg.generated.mbti", "third_party/mooncry_blake2/pkg.generated.mbti",
  ])
  let root = @env.current_dir().unwrap()
  let directory = root + "/results/check-moonbit-" + clock()
  ensure_io(make_directory(root + "/results", true))
  ensure_io(make_directory(directory, false))
  let path = directory + "/report.json"
  let records : Array[Json] = []
  let report : Json = {
    "schema_version": 1,
    "runner": "MoonBit",
    "status": "running",
    "passed": false,
    "link_checks_skipped": skip_links,
    "commands": records,
  }
  guard report is Object(fields) else { fail("Invalid report") }
  save(path, report.stringify(indent=2), exclusive=true)
  errdefer {
    fields["status"] = @json.to_json("failed")
    fields["commands"] = @json.to_json(records)
    save(path, report.stringify(indent=2), exclusive=false)
  }
  for command in commands {
    fields["current_command"] = @json.to_json(command)
    output(@json.to_json(command).stringify() + "\n")
    let result = @json.parse(
      run(command[0], @json.to_json(command[1:].to_owned()).stringify(), root),
    )
    guard result is Object(details) else { fail("Invalid process result") }
    let code : Int32 = @json.from_json(details["exit"])
    let error : String = @json.from_json(details["error"])
    if !error.is_empty() {
      error_output(error + "\n")
    }
    records.push({ "arguments": command, "exit": code })
    fields["commands"] = @json.to_json(records)
    if code != 0 {
      fields["status"] = @json.to_json("failed")
      save(path, report.stringify(indent=2), exclusive=false)
      error_output("Check stopped at failed command. Report: \{path}\n")
      return code
    }
    save(path, report.stringify(indent=2), exclusive=false)
  }
  fields.remove("current_command") |> ignore
  fields["status"] = @json.to_json("success")
  fields["passed"] = @json.to_json(true)
  save(path, report.stringify(indent=2), exclusive=false)
  output("All \{records.length()} checks passed. Report: \{path}\n")
  0
}

///|
fn main {
  let code = check(@env.args()) catch {
    error => {
      error_output(
        "Check failed: \{error}\nKeep evidence; no retry or permission changes performed.\n",
      )
      2
    }
  }
  if code != 0 {
    exit_status(code)
  }
}
