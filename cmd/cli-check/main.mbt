///|
async fn run_check(arguments : Array[String]) -> Unit {
  let mut profile = "debug"
  let mut skip_links = false
  let mut seen_profile = false
  let mut index = 1
  while index < arguments.length() {
    match arguments[index] {
      "--skip-links" if !skip_links => {
        skip_links = true
        index += 1
      }
      "--profile" if !seen_profile && index + 1 < arguments.length() => {
        seen_profile = true
        profile = arguments[index + 1]
        index += 2
      }
      _ =>
        fail(
          "Usage: cli-check [--profile debug|release] [--skip-links]; run from repository root",
        )
    }
  }
  ensure(["debug", "release"].contains(profile), "Invalid profile")
  let root = @env.current_dir().unwrap()
  let executable = root +
    "/_build/native/" +
    profile +
    "/build/cmd/moonrdiff/moonrdiff.exe"
  ensure(
    @fs.exists(executable),
    "Build cmd/moonrdiff for selected profile first",
  )
  if !@fs.exists(root + "/results") {
    @fs.mkdir(root + "/results")
  }
  let directory = root + "/results/cli-moonbit-" + @async.now().to_string()
  @fs.mkdir(directory)
  let log = @fs.create(directory + "/commands.log", allow_existing=false)
  defer log.close()
  let checks : Array[Json] = []
  let report : Json = {
    "schema_version": 2,
    "runner": "MoonBit",
    "platform": if windows {
      "nt"
    } else {
      "posix"
    },
    "checks": checks,
    "passed": false,
    "status": "running",
    "profile": profile,
    "link_checks_skipped": skip_links,
    "scope": "native CLI, byte verification, limits and exclusive file creation; all generated data",
  }
  let fields = object(report)
  let path = directory + "/report.json"
  @fs.write_file(path, report.stringify(indent=2), create_mode=CreateNew)
  errdefer {
    fields["status"] = @json.to_json("failed")
    fields["checks"] = @json.to_json(checks)
    @fs.write_file(
      path,
      report.stringify(indent=2),
      create_mode=TruncateExisting,
    )
  }
  let harness : Harness = { executable, directory, log, checks, }
  harness.accept(skip_links)
  let (code, output, errors) = @async.with_timeout(30000, () => {
    @process.collect_output(
      "python",
      ["scripts/check_cli_oracle.py", directory][:],
    )
  })
  log.write(
    (
      {
        "program": "python",
        "exit": code,
        "stdout": output.text(),
        "stderr": errors.text(),
      } : Json).stringify() +
    "\n",
  )
  ensure(
    code == 0 && errors.text().is_empty(),
    "Independent hashlib oracle failed: \{errors.text()}",
  )
  let oracle = @json.parse(output.text())
  ensure(
    object(oracle)["passed"] == @json.to_json(true),
    "Oracle did not report success",
  )
  fields["independent_oracle"] = oracle
  checks.push({ "command": "independent-hashlib-oracle", "exit": 0 })
  fields["checks"] = @json.to_json(checks)
  fields["passed"] = @json.to_json(true)
  fields["status"] = @json.to_json("success")
  @fs.write_file(path, report.stringify(indent=2), create_mode=TruncateExisting)
  @stdio.stdout.write(
    "Native CLI passed \{checks.length()} acceptance checks. Report: \{path}\n",
  )
}

///|
async fn main {
  run_check(@env.args()) catch {
    error => {
      @stdio.stderr.write(
        "CLI acceptance failed: \{error}\nKeep generated evidence; no retry or permission changes performed.\n",
      )
      exit_status(2)
    }
  }
}
