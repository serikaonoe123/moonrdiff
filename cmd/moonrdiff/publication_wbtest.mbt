///|
/// Synthetic writer faults; no disk exhaustion, permission changes or CLI flags.
async fn publication_fault_case(label : String, payload : Bytes) -> Unit {
  let destination = "_build/publication-" +
    label +
    "-" +
    @async.now().to_string()
  let mut staging : String? = None
  let message = try {
    publish_output(destination, path => {
      staging = Some(path)
      if !payload.is_empty() {
        let file = @fs.create(path, allow_existing=false, sync=NoSync)
        defer file.close()
        file.write(payload)
      }
      raise Usage("Simulated " + label + " failure")
    })
    "unexpected success"
  } catch {
    error => diagnostic(error)
  }
  assert_true(message.contains("Output was not published"))
  assert_true(message.contains("Simulated " + label + " failure"))
  assert_true(!@fs.exists(destination))
  let path = staging.unwrap()
  let directory = path[:path.length() - 5].to_owned()
  assert_true(message.contains(directory))
  assert_true(@fs.exists(directory))
  if payload.is_empty() {
    assert_true(!@fs.exists(path))
  } else {
    let saved = @fs.open(path, mode=ReadOnly)
    defer saved.close()
    assert_eq(saved.size(), payload.length().to_int64())
    assert_eq(saved.read_exactly_at(payload.length(), position=0L), payload)
  }
}

///|
async test "staging retains an empty directory when writer fails before opening" {
  publication_fault_case("before-write", b"")
}

///|
async test "staging retains partial bytes after a simulated write failure" {
  publication_fault_case("write", b"partial result")
}

///|
async test "staging retains complete bytes at a simulated sync failure boundary" {
  publication_fault_case("sync", b"complete result awaiting synchronization")
}

///|
async test "cleanup failure reports published target and retains directory evidence" {
  let destination = "_build/publication-cleanup-" + @async.now().to_string()
  let mut staging : String? = None
  let message = try {
    publish_output(destination, path => {
      staging = Some(path)
      let file = @fs.create(path, allow_existing=false, sync=NoSync)
      defer file.close()
      file.write(b"complete")
      file.sync(only_data=false)
      let retained = @fs.create(path + ".keep", allow_existing=false)
      defer retained.close()
      retained.write(b"cleanup must not recursively delete this")
      ({ "command": "test-only" } : Json)
    })
    "unexpected success"
  } catch {
    error => diagnostic(error)
  }
  assert_true(message.contains("Output was published; finalization failed"))
  assert_true(message.contains("Output: " + destination))
  let path = staging.unwrap()
  assert_true(!@fs.exists(path))
  assert_true(@fs.exists(path + ".keep"))
  let result = @fs.open(destination, mode=ReadOnly)
  defer result.close()
  assert_eq(result.read_exactly_at(8, position=0L), b"complete")
}
