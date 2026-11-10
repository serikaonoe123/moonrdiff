# Initial format contract

Status: explicit-instruction codec prototype, not a remote delta matcher.

## Supported delta data

- Magic: `0x72730236`, big-endian.
- Decode: END 0x00; short literals 0x01–0x40; length-prefixed literals 0x41–0x44; basis COPY 0x45–0x54.
- Parameter widths: 1, 2, 4, 8 bytes; big-endian unsigned representation.
- In-memory API rejects parameter values above 2,147,483,647 before conversion. Also rejects reserved opcodes, missing END, trailing bytes, truncated parameters/data, out-of-basis copies and output beyond caller budget.
- Encode: short literals up to 64 bytes, 4-byte lengths for longer literals, 4-byte offset/length COPY, final END. Empty literals are omitted. Encoder has no basis input and cannot validate COPY against its size; decoder performs that validation.
- The entire basis, delta and output are resident in memory. This is not a streaming API.
- Copy addresses the old basis, never the output under construction.
- Raw deltas do not authenticate the basis or result. The caller must bind them to the correct files; this prototype does not add a verification manifest.

## Planned signature profile

Target: `RS_RK_BLAKE2_SIG_MAGIC` (0x72730147). No signature reader, writer or checksum implementation exists yet. BLAKE2 variant/parameters, truncation and rolling-checksum vectors must be established against the fixed reference before advertising support. Strong-checksum dependency selection is pending.

## References

- [Format overview](https://librsync.github.io/page_formats.html)
- [Public magic numbers and recommended profile](https://github.com/librsync/librsync/blob/v2.3.4/src/librsync.h)
- [Opcode definitions](https://github.com/librsync/librsync/blob/v2.3.4/src/prototab.c)

These describe the format; this repository does not vendor or translate librsync implementation files.
