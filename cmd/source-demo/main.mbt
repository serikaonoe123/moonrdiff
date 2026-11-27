///|
extern "C" fn exit_status(code : Int32) -> Unit = "exit"

///|
fn object(value : Json) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("Expected JSON object")
  }
}

///|
fn digest(data : Bytes) -> String {
  let digits = "0123456789abcdef".to_array()
  let text = StringBuilder()
  for byte in @crypto.blake2b(data, 32) {
    let n = byte.to_int()
    text.write_char(digits[n / 16])
    text.write_char(digits[n % 16])
  }
  text.to_string()
}

///|
async fn execute(
  log : @fs.File,
  program : String,
  args : Array[String],
  cwd : String,
) -> Bytes {
  let (code, output, errors) = @process.collect_output(program, args[:], cwd~)
  log.write(
    (
      {
        "program": program,
        "arguments": args,
        "exit": code,
        "stdout_bytes": output.binary().length(),
        "stderr": errors.text(),
      } : Json).stringify() +
    "\n",
  )
  guard code == 0 else { fail("Command failed (\{code}): \{errors.text()}") }
  output.binary()
}

///|
async fn git(log : @fs.File, root : String, args : Array[String]) -> Bytes {
  let literal = ["--literal-pathspecs"]
  for arg in args {
    literal.push(arg)
  }
  execute(log, "git", literal, root)
}

///|
async fn snapshot(
  log : @fs.File,
  root : String,
  reference : String,
) -> (String, Array[String], Array[Json]) {
  let commit = @utf8.decode(
      git(log, root, [
        "rev-parse",
        "--verify",
        "--end-of-options",
        reference + "^{commit}",
      ]),
    )
    .trim()
    .to_owned()
  let listing = @utf8.decode(
    git(log, root, ["show", commit + ":packaging/files.txt"]),
  )
  let paths : Array[String] = []
  let inventory : Array[Json] = []
  for line in listing.split("\n") {
    let name = line.trim().to_owned()
    if name.is_empty() {
      continue
    }
    guard !name.contains("..") &&
      !name.contains("\\") &&
      !name.contains(":") &&
      name.to_array()[0] != '/' &&
      !paths.contains(name) else {
      fail("Unsupported or duplicate snapshot path")
    }
    let entry = @utf8.decode(
        git(log, root, [
          "ls-tree", "--format=%(objectmode) %(objecttype) %(objectname)", commit,
          "--", name,
        ]),
      )
      .trim()
      .to_owned()
    let fields = entry.split(" ").to_array()
    guard fields.length() == 3 && fields[0] == "100644" && fields[1] == "blob" else {
      fail("Snapshot input must be a regular committed file: " + name)
    }
    let data = git(log, root, ["show", commit + ":" + name])
    paths.push(name)
    inventory.push({
      "path": name,
      "bytes": data.length(),
      "git_blob": fields[2].to_owned(),
      "blake2b256": digest(data),
    })
  }
  guard !paths.is_empty() else { fail("Empty snapshot inventory") }
  (commit, paths, inventory)
}

///|
fn check_tar_epoch(data : Bytes) -> Unit raise {
  let mut offset = 0
  while offset + 512 <= data.length() {
    let mut empty = true
    for i in 0..<512 {
      if data[offset + i] != 0 {
        empty = false
      }
    }
    if empty {
      return
    }
    for i in 136..<148 {
      guard data[offset + i] == 0 ||
        data[offset + i] == 32 ||
        data[offset + i] == 48 else {
        fail("Git TAR timestamp is not epoch zero")
      }
    }
    let mut size = 0
    for i in 124..<136 {
      let byte = data[offset + i].to_int()
      if byte == 0 || byte == 32 {
        continue
      }
      guard byte >= 48 && byte <= 55 && size <= 67108864 / 8 else {
        fail("Invalid Git TAR size")
      }
      size = size * 8 + byte - 48
    }
    guard offset + 512 + size <= data.length() else {
      fail("Truncated Git TAR")
    }
    offset += 512 + (size + 511) / 512 * 512
  }
  fail("Missing Git TAR end")
}

///|
async fn archive(
  log : @fs.File,
  root : String,
  commit : String,
  paths : Array[String],
  kind : String,
) -> Bytes {
  // DOS ZIP dates cannot represent 1970; use its valid lower year instead.
  let date = if kind == "zip" {
    "1980-01-01T00:00:00Z"
  } else {
    "1970-01-01T00:00:00Z"
  }
  let args = ["archive", "--format=" + kind, "--mtime=" + date]
  if kind != "tar" {
    args.push("-9")
  }
  args.push(commit)
  args.push("--")
  for path in paths {
    args.push(path)
  }
  let data = git(log, root, args)
  guard data.length() <= 67108864 else { fail("Demo archive exceeds 64 MiB") }
  if kind == "tar" {
    check_tar_epoch(data)
  }
  data
}

///|
async fn read(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  guard size >= 0L && size <= 67108864L else {
    fail("Demo read exceeds 64 MiB")
  }
  file.read_exactly_at(size.to_int(), position=0L)
}

///|
async fn size(path : String) -> Int32 {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  file.size().to_int()
}

///|
fn plan(delta : Int32, full : Int32) -> Json {
  (
    {
      "choice": if delta < full {
        "delta"
      } else {
        "full"
      },
      "file_bytes": if delta < full {
        delta
      } else {
        full
      },
    } : Json)
}

///|
async fn run_demo(args : Array[String]) -> Unit {
  let options : Map[String, String] = Map([])
  let mut index = 1
  while index < args.length() {
    guard index + 1 < args.length() &&
      ["--profile", "--basis-ref", "--target-ref"].contains(args[index]) &&
      !options.contains(args[index]) else {
      fail("Invalid or repeated demo option")
    }
    options[args[index]] = args[index + 1]
    index += 2
  }
  let profile = options.get("--profile").unwrap_or("release")
  guard ["debug", "release"].contains(profile) else { fail("Invalid profile") }
  let root = @env.current_dir().unwrap()
  let executable = root +
    "/_build/native/" +
    profile +
    "/build/cmd/moonrdiff/moonrdiff.exe"
  guard @fs.exists(executable) else {
    fail("Build cmd/moonrdiff for selected profile first")
  }
  if !@fs.exists("results") {
    @fs.mkdir("results")
  }
  let directory = root +
    "/results/source-update-moonbit-" +
    @async.now().to_string()
  @fs.mkdir(directory, permission=0o700)
  let log = @fs.create(directory + "/commands.log", allow_existing=false)
  defer log.close()
  let cases : Array[Json] = []
  let report : Json = {
    "schema_version": 2,
    "status": "running",
    "archive_backend": "git-archive-explicit-dates-v2",
    "hash_algorithm": "blake2b-256",
    "profile": profile,
    "cases": cases,
    "directory": directory,
  }
  let fields = object(report)
  let report_path = directory + "/report.json"
  @fs.write_file(report_path, report.stringify(indent=2), create_mode=CreateNew)
  errdefer {
    fields["status"] = @json.to_json("failed")
    fields["cases"] = @json.to_json(cases)
    @async.protect_from_cancel(() => {
      @fs.write_file(
        report_path,
        report.stringify(indent=2),
        create_mode=TruncateExisting,
      )
    })
  }
  let (old_commit, old_paths, old_inventory) = snapshot(
    log,
    root,
    options
    .get("--basis-ref")
    .unwrap_or("e09db0b71ef6386f30aa5e5aebd2a2c619013be9"),
  )
  let (new_commit, new_paths, new_inventory) = snapshot(
    log,
    root,
    options
    .get("--target-ref")
    .unwrap_or("4013e9ca62b54eb314a0444f902962eebbdd039f"),
  )
  fields["basis_commit"] = @json.to_json(old_commit)
  fields["target_commit"] = @json.to_json(new_commit)
  fields["input_files"] = { "basis": old_inventory, "target": new_inventory }
  fields["source_commit"] = @json.to_json(
    @utf8.decode(git(log, root, ["rev-parse", "HEAD"])).trim().to_owned(),
  )
  fields["git_version"] = @json.to_json(
    @utf8.decode(git(log, root, ["--version"])).trim().to_owned(),
  )
  fields["executable_blake2b256"] = @json.to_json(digest(read(executable)))
  for kind in ["tar", "zip", "tar.gz"] {
    let folder = directory + "/" + kind
    let sender = folder + "/sender"
    let receiver = folder + "/receiver"
    @fs.mkdir(folder)
    @fs.mkdir(sender)
    @fs.mkdir(receiver)
    let old = archive(log, root, old_commit, old_paths, kind)
    let new = archive(log, root, new_commit, new_paths, kind)
    let basis = receiver + "/old." + kind
    let target = sender + "/new." + kind
    let sig = sender + "/basis.sig"
    let delta = sender + "/update.delta"
    let manifest = receiver + "/binding.json"
    let restored = receiver + "/restored." + kind
    @fs.write_file(basis, old, create_mode=CreateNew)
    @fs.write_file(target, new, create_mode=CreateNew)
    let records : Array[Json] = []
    records.push(
      @json.parse(
        @utf8.decode(
          execute(
            log,
            executable,
            ["signature", basis, sig, "--block-size", "2048"],
            receiver,
          ),
        ),
      ),
    )
    let present = @fs.readdir(sender)
    guard present.length() == 2 &&
      present.contains("basis.sig") &&
      present.contains("new." + kind) else {
      fail("Unexpected sender inputs")
    }
    records.push(
      @json.parse(
        @utf8.decode(
          execute(
            log,
            executable,
            [
              "delta",
              "basis.sig",
              "new." + kind,
              "update.delta",
              "--basis-size",
              old.length().to_string(),
            ],
            sender,
          ),
        ),
      ),
    )
    records.push(
      @json.parse(
        @utf8.decode(
          execute(
            log,
            executable,
            ["manifest", basis, target, delta, manifest],
            folder,
          ),
        ),
      ),
    )
    records.push(
      @json.parse(
        @utf8.decode(
          execute(
            log,
            executable,
            ["patch", basis, delta, restored, "--manifest", manifest],
            receiver,
          ),
        ),
      ),
    )
    records.push(
      @json.parse(
        @utf8.decode(
          execute(log, executable, ["verify", target, restored], folder),
        ),
      ),
    )
    guard read(restored) == new && read(basis) == old else {
      fail("Bound restore or original preservation failed")
    }
    let full_identity : Json = {
      "schema": "moonrdiff-example-full-v1",
      "bytes": new.length(),
      "blake2b256": digest(new),
    }
    let full_manifest = receiver + "/full-target.json"
    @fs.write_file(
      full_manifest,
      full_identity.stringify() + "\n",
      create_mode=CreateNew,
    )
    let sig_size = size(sig)
    let payload = size(delta) + size(manifest)
    let first = sig_size + payload
    let full = new.length() + size(full_manifest)
    let selected = if first < full {
      restored
    } else {
      let path = receiver + "/full-delivery." + kind
      @fs.write_file(path, read(target), create_mode=CreateNew)
      let identity = object(@json.parse(@utf8.decode(read(full_manifest))))
      let expected_size : Int32 = @json.from_json(identity["bytes"])
      let expected_hash : String = @json.from_json(identity["blake2b256"])
      let delivered = read(path)
      guard delivered.length() == expected_size &&
        digest(delivered) == expected_hash else {
        fail("Full identity mismatch")
      }
      records.push(
        @json.parse(
          @utf8.decode(
            execute(log, executable, ["verify", target, path], folder),
          ),
        ),
      )
      path
    }
    guard read(selected) == new else {
      fail("Selected delivery differs from target")
    }
    let row : Json = {
      "format": kind,
      "basis_bytes": old.length(),
      "target_bytes": new.length(),
      "basis_blake2b256": digest(old),
      "target_blake2b256": digest(new),
      "restored_blake2b256": digest(read(restored)),
      "selected_blake2b256": digest(read(selected)),
      "signature_bytes": sig_size,
      "delta_bytes": size(delta),
      "manifest_bytes": size(manifest),
      "full_target_manifest_bytes": size(full_manifest),
      "full_delivery_bytes": full,
      "first_exchange_bytes": first,
      "first_exchange_ratio": first.to_double() / new.length().to_double(),
      "delta_plus_manifest_bytes": payload,
      "offline_plan": plan(first, full),
      "signature_reuse_plan": {
        "choice": if payload < full {
          "delta"
        } else {
          "full"
        },
        "remaining_file_bytes": if payload < full {
          payload
        } else {
          full
        },
      },
      "signature_already_sent_total_bytes": sig_size +
      (if payload < full { payload } else { full }),
      "matched": true,
      "original_preserved": true,
      "sender_directory_has_no_basis": !@fs.exists(sender + "/old." + kind),
      "commands": records,
    }
    cases.push(row)
    fields["cases"] = @json.to_json(cases)
    @fs.write_file(
      report_path,
      report.stringify(indent=2),
      create_mode=TruncateExisting,
    )
    @stdio.stdout.write(row.stringify() + "\n")
  }
  fields["status"] = @json.to_json("success")

  @fs.write_file(
    report_path,
    report.stringify(indent=2),
    create_mode=TruncateExisting,
  )
  @stdio.stdout.write("Report: " + report_path + "\n")
}

///|
async fn main {
  run_demo(@env.args()) catch {
    error => {
      @stdio.stderr.write(
        "Source demo failed: \{error}\nKeep generated files; no retry performed.\n",
      )
      exit_status(2)
    }
  }
}
