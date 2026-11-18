///|
/// Node adapters provide bounded local I/O and SHA-256, not update decisions.
extern "js" fn read_file(path : String, limit : Int32) -> String =
  #| (path, limit) => {
  #|   const fs = require('node:fs'); let fd;
  #|   try {
  #|     fd = fs.openSync(path, 'r');
  #|     const stat = fs.fstatSync(fd);
  #|     if (!stat.isFile() || stat.size > limit) throw Error('file limit or type');
  #|     const b = Buffer.alloc(stat.size); let n = 0;
  #|     while (n < b.length) { const r = fs.readSync(fd, b, n, b.length - n, null); if (!r) throw Error('short read'); n += r; }
  #|     if (fs.readSync(fd, Buffer.alloc(1), 0, 1, null)) throw Error('file grew');
  #|     return JSON.stringify({ data: b.toString('hex'), error: '' });
  #|   } catch (e) { return JSON.stringify({ data: '', error: String(e) }); }
  #|   finally { if (fd !== undefined) fs.closeSync(fd); }
  #| }

///|
extern "js" fn write_file(path : String, data : Bytes) -> String =
  #| (path, data) => {
  #|   try { require('node:fs').writeFileSync(path, data, { flag: 'wx' }); return ''; }
  #|   catch (e) { return String(e); }
  #| }

///|
extern "js" fn sha256(data : Bytes) -> String =
  #| data => require('node:crypto').createHash('sha256').update(data).digest('hex')

///|
extern "js" fn finish(text : String, code : Int32) -> Unit =
  #| (text, code) => { (code ? process.stderr : process.stdout).write(text + '\n'); process.exitCode = code; }
