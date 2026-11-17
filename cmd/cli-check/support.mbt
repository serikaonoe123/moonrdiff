///|
extern "C" fn exit_status(code : Int32) -> Unit = "exit"

///|
#cfg(platform="windows")
let windows = true

///|
#cfg(not(platform="windows"))
let windows = false

///|
#cfg(platform="windows")
#borrow(existing, created)
extern "C" fn hardlink(existing : String, created : String) -> Int32 = "moonrdiff_check_hardlink"

///|
#cfg(not(platform="windows"))
#borrow(existing, created)
extern "C" fn hardlink(existing : Bytes, created : Bytes) -> Int32 = "moonrdiff_check_hardlink"

///|
#cfg(platform="windows")
fn create_hardlink(existing : String, created : String) -> Unit raise {
  let code = hardlink(existing + "\u0000", created + "\u0000")
  ensure(
    code == 0,
    "Hard link creation failed (OS code \{code}); no retry or access-rule changes",
  )
}

///|
#cfg(not(platform="windows"))
fn create_hardlink(existing : String, created : String) -> Unit raise {
  let code = hardlink(
    @utf8.encode(existing + "\u0000"),
    @utf8.encode(created + "\u0000"),
  )
  ensure(
    code == 0,
    "Hard link creation failed (OS code \{code}); no retry or access-rule changes",
  )
}

///|
fn ensure(value : Bool, message : String) -> Unit raise {
  guard value else { fail(message) }
}

///|
fn object(value : Json) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("Expected JSON object")
  }
}

///|
struct Result {
  code : Int32
  output : String
  errors : String
}

///|
fn Result::json(self : Result) -> Json raise {
  @json.parse(self.output)
}

///|
async fn capture(executable : String, args : Array[String]) -> Result {
  @async.with_timeout(30000, () => {
    let (code, output, errors) = @process.collect_output(executable, args[:])
    { code, output: output.text(), errors: errors.text(), }
  })
}

///|
struct Harness {
  executable : String
  directory : String
  log : @fs.File
  checks : Array[Json]
}

///|
async fn Harness::record(
  self : Harness,
  args : Array[String],
  result : Result,
) -> Unit {
  self.log.write(
    (
      {
        "arguments": args,
        "exit": result.code,
        "stdout": result.output,
        "stderr": result.errors,
      } : Json).stringify() +
    "\n",
  )
}

///|
async fn Harness::invoke(
  self : Harness,
  args : Array[String],
  code~ : Int32 = 0,
) -> Result {
  let result = capture(self.executable, args)
  self.record(args, result)
  ensure(
    result.code == code,
    "Unexpected CLI exit for \{@json.to_json(args).stringify()}: expected \{code}, got \{result.code}; \{result.errors}",
  )
  if code == 2 {
    ensure(
      !result.errors.is_empty() && result.output.is_empty(),
      "Error must use stderr without success stdout",
    )
  } else {
    ensure(result.errors.is_empty(), "Unexpected CLI stderr")
  }
  self.checks.push({
    "command": if args.is_empty() {
      "missing"
    } else {
      args[0]
    },
    "exit": code,
  })
  result
}

///|
async fn Harness::ok(self : Harness, args : Array[String]) -> Json {
  self.invoke(args).json()
}

///|
async fn Harness::reject(self : Harness, args : Array[String]) -> String {
  self.invoke(args, code=2).errors
}

///|
async fn read(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  ensure(
    size >= 0L && size <= 67108864L,
    "Acceptance fixture read exceeds 64 MiB",
  )
  file.read_exactly_at(size.to_int(), position=0L)
}

///|
async fn write(path : String, data : Bytes, replace~ : Bool = false) -> Unit {
  @fs.write_file(
    path,
    data,
    create_mode=if replace { TruncateExisting } else { CreateNew },
  )
}

///|
fn pattern(length : Int32) -> Bytes {
  Bytes::makei(length, i => (i % 256).to_byte())
}

///|
async fn Harness::late_conflict(self : Harness) -> Unit {
  let basis = self.directory + "/stage-basis.bin"
  let stream = @fs.create(basis, allow_existing=false)
  let block = pattern(65536)
  for _ in 0..<512 {
    stream.write(block)
  }
  stream.close()
  let reference = self.directory + "/stage-reference.sig"
  ignore(self.ok(["signature", basis, reference]))
  for name in @fs.readdir(self.directory) {
    ensure(
      !name.has_prefix("stage-reference.sig.moonrdiff-stage-"),
      "Successful output retained a staging directory",
    )
  }
  let destination = self.directory + "/stage-race.sig"
  let arguments = ["signature", basis, destination]
  let stdout = self.directory + "/stage-race.stdout"
  let stderr = self.directory + "/stage-race.stderr"
  @async.with_timeout(30000, () => {
    @async.with_task_group() <| group => {
      let process = @process.spawn(
        group,
        self.executable,
        arguments[:],
        stdout=@process.redirect_to_file(stdout, create_mode=CreateNew),
        stderr=@process.redirect_to_file(stderr, create_mode=CreateNew),
      )
      let mut observed : String? = None
      while process.try_wait() is None {
        for name in @fs.readdir(self.directory) {
          if name.has_prefix("stage-race.sig.moonrdiff-stage-") {
            let candidate = self.directory + "/" + name
            if @fs.exists(candidate + "/data") {
              let file = @fs.open(candidate + "/data", mode=ReadOnly)
              let size = file.size()
              file.close()
              if size > 0L {
                observed = Some(candidate)
              }
            }
          }
        }
        if observed is Some(_) {
          break
        }
        @async.sleep(1)
      }
      let staged = observed.unwrap_or_else(() => {
        fail("Did not observe staging; no retry performed")
      })
      ensure(
        !@fs.exists(destination),
        "Destination appeared before controlled conflict",
      )
      let marker = b"existing destination from concurrent writer"
      write(destination, marker)
      let result : Result = {
        code: process.wait(),
        output: @utf8.decode(read(stdout)),
        errors: @utf8.decode(read(stderr)),
      }
      self.record(arguments, result)
      ensure(
        result.code == 2 && result.output.is_empty(),
        "Late conflict emitted success",
      )
      ensure(
        result.errors.contains("Output was not published"),
        "Missing unpublished-output diagnostic",
      )
      ensure(read(destination) == marker, "Late conflict replaced destination")
      ensure(
        read(staged + "/data") == read(reference),
        "Complete staging output was not retained",
      )
    }
  })
  self.checks.push({
    "command": "staged-publication-conflict",
    "exit": 2,
    "no_success_json": true,
    "destination_preserved": true,
    "staged_complete_output_retained": true,
  })
}
