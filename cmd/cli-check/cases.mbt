///|
async fn Harness::accept(self : Harness, skip_links : Bool) -> Unit {
  let dir = self.directory
  let basis = dir + "/旧文件 空格.bin"
  let target = dir + "/新文件.bin"
  let sig = dir + "/摘要.sig"
  let delta = dir + "/更新.delta"
  let restored = dir + "/还原.bin"
  let old = pattern(2048) + b"tail"
  let new = b"prefix" + old[512:].to_owned() + old[:512].to_owned() + b"suffix"
  write(basis, old)
  write(target, new)
  ensure(
    self.invoke(["--help"]).output.contains("signature BASIS"),
    "Missing help text",
  )
  let info = object(self.ok(["signature", basis, sig, "--block-size", "32"]))
  ensure(
    info["basis_size"] == @json.to_json(old.length()),
    "Incorrect basis size",
  )
  ignore(
    self.ok([
      "delta",
      sig,
      target,
      delta,
      "--basis-size",
      old.length().to_string(),
    ]),
  )
  ignore(self.ok(["patch", basis, delta, restored]))
  ensure(read(restored) == new, "Basic restore differs")
  ensure(
    object(self.ok(["verify", target, restored]))["matched"] ==
    @json.to_json(true),
    "Verify must match",
  )
  ensure(
    object(self.invoke(["verify", basis, restored], code=1).json())["matched"] ==
    @json.to_json(false),
    "Verify must detect mismatch",
  )

  // Exact EOF and mismatches surrounding the 64 KiB boundary.
  let expected = dir + "/verify-expected.bin"
  let actual = dir + "/verify-actual.bin"
  write(expected, b"")
  write(actual, b"")
  for length in [0, 1, 65535, 65536, 65537, 131073] {
    let data = pattern(length)
    write(expected, data, replace=true)
    write(actual, data, replace=true)
    let expected_result : Json = {
      "command": "verify",
      "matched": true,
      "expected_bytes": length,
      "actual_bytes": length,
    }
    ensure(
      self.ok(["verify", expected, actual, "--max-input", length.to_string()]) ==
      expected_result,
      "Exact verify result differs",
    )
    let positions : Array[Int32] = []
    for position in [0, 65535, 65536, length - 1] {
      if position >= 0 && position < length && !positions.contains(position) {
        positions.push(position)
      }
    }
    positions.sort()
    for position in positions {
      let changed = data.to_array()
      changed[position] = (changed[position].to_int() ^ 255).to_byte()
      write(actual, Bytes::from_array(changed[:]), replace=true)
      let mismatch : Json = {
        "command": "verify",
        "matched": false,
        "expected_bytes": length,
        "actual_bytes": length,
      }
      ensure(
        self.invoke(["verify", expected, actual], code=1).json() == mismatch,
        "Boundary mismatch was not detected",
      )
    }
    write(actual, data + b"x", replace=true)
    for
      (left, right, left_size, right_size) in [
        (expected, actual, length, length + 1),
        (actual, expected, length + 1, length),
      ] {
      let mismatch : Json = {
        "command": "verify",
        "matched": false,
        "expected_bytes": left_size,
        "actual_bytes": right_size,
      }
      ensure(
        self.invoke(["verify", left, right], code=1).json() == mismatch,
        "EOF mismatch result differs",
      )
      ensure(
        self
        .reject(["verify", left, right, "--max-input", length.to_string()])
        .contains("Input byte limit exceeded"),
        "Length mismatch bypassed input budget",
      )
    }
    ensure(
      read(expected) == data && read(actual) == data + b"x",
      "Verify modified inputs",
    )
  }
  ignore(self.reject(["verify", expected, dir]))
  ignore(self.reject(["verify", dir + "/missing-verify", actual]))
  ignore(self.reject(["verify", expected, actual, "--chunk-size", "1"]))

  // Invalid arguments and inputs must not create a final output.
  let absent = dir + "/must-not-exist"
  ignore(self.reject([]))
  ignore(self.reject(["unknown"]))
  ignore(self.reject(["signature", basis]))
  ignore(self.reject(["delta", sig, target, absent]))
  ignore(self.reject(["delta", sig, target, absent, "--basis-size", "0"]))
  ignore(self.reject(["signature", basis, absent, "--block-size", "0"]))
  for value in ["-1", "1e3", "2147483648", ""] {
    ignore(self.reject(["signature", basis, absent, "--max-input", value]))
  }
  ignore(self.reject(["signature", basis, absent, "--unknown", "1"]))
  ignore(
    self.reject([
      "signature", basis, absent, "--max-input", "1", "--max-input", "2",
    ]),
  )
  ensure(
    self
    .reject(["signature", basis, absent, "--max-input", "1"])
    .contains("Input byte limit exceeded"),
    "Missing input budget diagnostic",
  )
  ignore(self.reject(["signature", basis, absent, "--max-output", "1"]))
  ignore(self.reject(["signature", dir + "/missing", absent]))
  ignore(self.reject(["signature", dir, absent]))
  ensure(
    self
    .reject(["patch", basis, delta, absent, "--max-output", "1"])
    .contains("Output budget exceeded"),
    "Missing output budget diagnostic",
  )
  let bad = dir + "/invalid.delta"
  write(bad, b"bad format")
  ignore(self.reject(["patch", basis, bad, absent]))
  ensure(!@fs.exists(absent), "Invalid command created final output")

  // Existing outputs, same-path inputs and filesystem aliases remain intact.
  let before = read(sig)
  ignore(self.reject(["signature", basis, sig]))
  ensure(read(sig) == before, "Existing output was modified")
  ignore(self.reject(["signature", basis, basis]))
  ensure(read(basis) == old, "Same-path input was modified")
  if !skip_links {
    let linked = dir + "/hardlink.bin"
    create_hardlink(basis, linked)
    ignore(self.reject(["patch", basis, delta, linked]))
    ensure(
      read(linked) == old && read(basis) == old,
      "Hard link input was modified",
    )
    if !windows {
      let symbolic = dir + "/symlink.bin"
      @fs.symlink(symbolic, target=basis)
      ignore(self.reject(["patch", basis, delta, symbolic]))
      ensure(
        @fs.kind(symbolic, follow_symlink=false) == SymLink &&
        read(basis) == old,
        "Symbolic link input was modified",
      )
    }
  }

  // Two actual writers cannot both claim one output.
  let race_output = dir + "/race.sig"
  let race_args = ["signature", basis, race_output]
  let results = @async.all([
    () => capture(self.executable, race_args),
    () => capture(self.executable, race_args),
  ])
  let exits = results.map(result => result.code)
  exits.sort()
  ensure(exits == [0, 2], "Concurrent writers did not have exactly one winner")
  for result in results {
    self.record(race_args, result)
    ensure(
      if result.code == 2 {
        result.output.is_empty() && !result.errors.is_empty()
      } else {
        result.errors.is_empty()
      },
      "Race result used wrong output stream",
    )
  }
  let reference = dir + "/reference.sig"
  ignore(self.ok(["signature", basis, reference]))
  ensure(read(race_output) == read(reference), "Race winner output differs")
  self.checks.push({
    "command": "concurrent-exclusive-create",
    "exit_codes": [0, 2],
  })

  // Empty input and zero output budget, then IO partition invariance.
  let empty = dir + "/empty.bin"
  let empty_sig = dir + "/empty.sig"
  let empty_delta = dir + "/empty.delta"
  let empty_restore = dir + "/empty-restored.bin"
  write(empty, b"")
  ignore(self.ok(["signature", empty, empty_sig, "--max-input", "0"]))
  ignore(
    self.ok([
      "delta", empty_sig, empty, empty_delta, "--basis-size", "0", "--max-output",
      "5",
    ]),
  )
  ignore(
    self.ok(["patch", empty, empty_delta, empty_restore, "--max-output", "0"]),
  )
  ensure(
    read(empty_restore) == b"" && read(basis) == old && read(target) == new,
    "Empty restore or source preservation failed",
  )
  for chunk in [1, 7, 128, 65536] {
    let output = dir + "/chunk-\{chunk}.sig"
    let info = object(
      self.ok([
        "signature",
        basis,
        output,
        "--block-size",
        "32",
        "--chunk-size",
        chunk.to_string(),
      ]),
    )
    ensure(
      info["incremental"] == @json.to_json(true) &&
      info["chunk_size"] == @json.to_json(chunk),
      "Signature did not report incremental chunk size",
    )
    ensure(read(output) == read(sig), "Signature depends on IO partition")
  }
  for chunk in ["0", "65537"] {
    ignore(self.reject(["signature", basis, absent, "--chunk-size", chunk]))
  }
  ignore(self.reject(["signature", basis, absent, "--block-size", "1048577"]))
  ensure(!@fs.exists(absent), "Invalid signature created output")

  // The independent hashlib/struct oracle checks the complete 8 MiB signature.
  let large_basis = dir + "/multi-chunk.bin"
  let large_sig = dir + "/multi-chunk.sig"
  write(large_basis, pattern(8388608))
  let large_info = object(
    self.ok([
      "signature", large_basis, large_sig, "--block-size", "4096", "--chunk-size",
      "8191",
    ]),
  )
  ensure(
    large_info["basis_size"] == @json.to_json(8388608),
    "Incorrect multi-chunk size",
  )

  let small_basis = dir + "/small-basis.bin"
  let small_delta = dir + "/small.delta"
  let small_patch = b"rs\x02\x36\x45\x08\x03\x03NEW\x45\x00\x08\x00"
  write(small_basis, b"abcdefghijk")
  write(small_delta, small_patch)
  for chunk in [1, 2, 7, 65536] {
    let output = dir + "/patch-chunk-\{chunk}.bin"
    let info = object(
      self.ok([
        "patch",
        small_basis,
        small_delta,
        output,
        "--chunk-size",
        chunk.to_string(),
      ]),
    )
    ensure(
      info["incremental"] == @json.to_json(true) &&
      read(output) == b"ijkNEWabcdefgh",
      "Partitioned patch differs",
    )
  }
  ignore(
    self.reject([
      "patch", small_basis, small_delta, absent, "--max-instructions", "2",
    ]),
  )
  ignore(
    self.reject(["patch", small_basis, small_delta, absent, "--chunk-size", "0"]),
  )
  ignore(
    self.reject([
      "patch", small_basis, small_delta, absent, "--chunk-size", "65537",
    ]),
  )
  for
    index, data in [
      small_patch[:small_patch.length() - 1].to_owned(),
      b"rs\x02\x36\x45\xff\x01\x00",
      small_patch + b"x",
    ] {
    let broken = dir + "/broken-\{index}.delta"
    write(broken, data)
    ignore(
      self.reject(["patch", small_basis, broken, absent, "--chunk-size", "1"]),
    )
  }
  ensure(!@fs.exists(absent), "Invalid patch created output")
  let large_patch = dir + "/large-copy.delta"
  let large_restored = dir + "/large-copy.bin"
  write(large_patch, b"rs\x02\x36\x4f\x00\x00\x00\x00\x00\x80\x00\x00\x00")
  ignore(self.ok(["patch", large_basis, large_patch, large_restored]))
  ensure(read(large_restored) == read(large_basis), "Large copy differs")

  let mut previous : Bytes? = None
  for chunk in [1, 2, 7, 65536] {
    let output = dir + "/delta-chunk-\{chunk}.delta"
    let info = object(
      self.ok([
        "delta",
        sig,
        target,
        output,
        "--basis-size",
        old.length().to_string(),
        "--chunk-size",
        chunk.to_string(),
      ]),
    )
    ensure(
      info["incremental"] == @json.to_json(true),
      "Delta did not report incremental mode",
    )
    let data = read(output)
    if previous is Some(bytes) {
      ensure(data == bytes, "Delta depends on IO partition")
    }
    previous = Some(data)
  }
  for chunk in ["0", "65537"] {
    ignore(
      self.reject([
        "delta",
        sig,
        target,
        absent,
        "--basis-size",
        old.length().to_string(),
        "--chunk-size",
        chunk,
      ]),
    )
  }
  ignore(
    self.reject([
      "delta",
      sig,
      target,
      absent,
      "--basis-size",
      old.length().to_string(),
      "--max-output",
      "5",
    ]),
  )
  ensure(!@fs.exists(absent), "Invalid delta created output")
  let fallback = dir + "/fallback.delta"
  let fallback_restore = dir + "/fallback.bin"
  ignore(
    self.ok([
      "delta",
      sig,
      target,
      fallback,
      "--basis-size",
      old.length().to_string(),
      "--max-checks",
      "0",
    ]),
  )
  ignore(self.ok(["patch", basis, fallback, fallback_restore]))
  ensure(read(fallback_restore) == new, "Literal fallback restore differs")

  let manifest = dir + "/binding.json"
  ignore(self.ok(["manifest", basis, target, delta, manifest]))
  let binding = @json.parse(@utf8.decode(read(manifest)))
  let bound_result = dir + "/bound.bin"
  ensure(
    object(
      self.ok(["patch", basis, delta, bound_result, "--manifest", manifest]),
    )["manifest_verified"] ==
    @json.to_json(true),
    "Binding was not verified",
  )
  ensure(read(bound_result) == new, "Bound result differs")
  ignore(self.reject(["manifest", basis, target, delta, manifest]))
  let wrong_basis = dir + "/wrong-basis.bin"
  let changed = old.to_array()
  changed[0] = (changed[0].to_int() ^ 1).to_byte()
  write(wrong_basis, Bytes::from_array(changed[:]))
  ignore(
    self.reject(["patch", wrong_basis, delta, absent, "--manifest", manifest]),
  )
  let wrong_delta = dir + "/wrong.delta"
  let changed = read(delta).to_array()
  changed[changed.length() - 1] = (changed[changed.length() - 1].to_int() ^ 1).to_byte()
  write(wrong_delta, Bytes::from_array(changed[:]))
  ignore(
    self.reject(["patch", basis, wrong_delta, absent, "--manifest", manifest]),
  )
  for
    (field, value) in [
      ("schema_version", @json.to_json(2)),
      ("algorithm", @json.to_json("sha256")),
      ("extra", @json.to_json(0)),
    ] {
    let altered = @json.parse(binding.stringify())
    object(altered)[field] = value
    let path = dir + "/binding-" + field + ".json"
    write(path, @utf8.encode(altered.stringify()))
    ignore(self.reject(["patch", basis, delta, absent, "--manifest", path]))
  }
  for key in ["basis", "target", "delta"] {
    let altered = @json.parse(binding.stringify())
    object(object(altered)[key])["hash"] = @json.to_json(
      "0000000000000000000000000000000000000000000000000000000000000000",
    )
    let path = dir + "/binding-" + key + "-bad.json"
    write(path, @utf8.encode(altered.stringify()))
    ignore(self.reject(["patch", basis, delta, absent, "--manifest", path]))
  }
  let duplicate = dir + "/duplicate.json"
  let original_json = @utf8.decode(read(manifest))
  let duplicate_json = original_json.replace(
    old="\"schema_version\": 1",
    new="\"schema_version\": 1, \"schema_version\": 1",
  )
  ensure(
    duplicate_json != original_json,
    "Duplicate-key fixture was not changed",
  )
  write(duplicate, @utf8.encode(duplicate_json))
  ignore(self.reject(["patch", basis, delta, absent, "--manifest", duplicate]))
  ignore(
    self.reject([
      "patch", basis, delta, absent, "--manifest", manifest, "--manifest", manifest,
    ]),
  )
  ignore(
    self.reject([
      "patch",
      basis,
      delta,
      absent,
      "--manifest",
      dir + "/missing-manifest",
    ]),
  )
  ensure(!@fs.exists(absent), "Bad binding created output")

  let unrelated = dir + "/unrelated.bin"
  let bad_association = dir + "/unrelated-binding.json"
  write(unrelated, b"unrelated result")
  ignore(self.ok(["manifest", basis, unrelated, delta, bad_association]))
  ignore(
    self.reject(["patch", basis, delta, absent, "--manifest", bad_association]),
  )
  ensure(!@fs.exists(absent), "Unrelated binding created output")
  ignore(
    self.reject(["manifest", basis, target, delta, absent, "--max-output", "1"]),
  )
  ensure(!@fs.exists(absent), "Manifest budget failure created output")
  self.late_conflict()
}
