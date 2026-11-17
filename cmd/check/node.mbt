///|
extern "js" fn clock() -> String =
  #| () => Date.now().toString()

///|
extern "js" fn output(text : String) -> Unit =
  #| text => { process.stdout.write(text); }

///|
extern "js" fn error_output(text : String) -> Unit =
  #| text => { process.stderr.write(text); }

///|
/// The adapter only executes argv arrays; command order and checks are MoonBit.
extern "js" fn run(program : String, args : String, cwd : String) -> String =
  #| (program, args, cwd) => {
  #|   try {
  #|     const r = require('node:child_process').spawnSync(program, JSON.parse(args), { cwd, stdio: 'inherit', shell: false });
  #|     return JSON.stringify({ exit: (r.status ?? 2) | 0, error: r.error ? String(r.error) : (r.signal ? `Child terminated: ${r.signal}` : '') });
  #|   } catch (e) { return JSON.stringify({ exit: 2, error: String(e) }); }
  #| }

///|
extern "js" fn make_directory(path : String, allow_existing : Bool) -> String =
  #| (path, allowExisting) => {
  #|   try {
  #|     const fs = require('node:fs');
  #|     if (!(allowExisting && fs.statSync(path, { throwIfNoEntry: false })?.isDirectory())) fs.mkdirSync(path);
  #|     return '';
  #|   } catch (e) { return String(e); }
  #| }

///|
extern "js" fn write_report(
  path : String,
  text : String,
  exclusive : Bool,
) -> String =
  #| (path, text, exclusive) => {
  #|   try { require('node:fs').writeFileSync(path, text, { encoding: 'utf8', flag: exclusive ? 'wx' : 'w' }); return ''; }
  #|   catch (e) { return String(e); }
  #| }

///|
fn ensure_io(error : String) -> Unit raise {
  guard error.is_empty() else { fail(error) }
}

///|
fn save(path : String, text : String, exclusive~ : Bool) -> Unit raise {
  ensure_io(write_report(path, text, exclusive))
}
