# Initial format contract

Status: signature generation/reading and explicit-instruction codec; automatic in-memory delta matching is available.

## Supported delta data

- Magic: `0x72730236`, big-endian.
- Decode: END 0x00; short literals 0x01–0x40; length-prefixed literals 0x41–0x44; basis COPY 0x45–0x54.
- Parameter widths: 1, 2, 4, 8 bytes; big-endian unsigned representation.
- In-memory API rejects parameter values above 2,147,483,647 before conversion. Also rejects reserved opcodes, missing END, trailing bytes, truncated parameters/data, out-of-basis copies and output beyond caller budget.
- Encode: short literals up to 64 bytes, 4-byte lengths for longer literals, 4-byte offset/length COPY, final END. Empty literals are omitted. Encoder has no basis input and cannot validate COPY against its size; decoder performs that validation.
- The entire basis, delta and output are resident in memory. This is not a streaming API.
- Copy addresses the old basis, never the output under construction.
- Raw deltas do not authenticate the basis or result. The caller must bind them to the correct files; this prototype does not add a verification manifest.

## Supported signature profile

`RS_RK_BLAKE2_SIG_MAGIC` (0x72730147) only. Header has positive Int32 block size and strong length 1..32. Each record contains a 32-bit unsigned weak checksum followed by the truncated strong digest. The last basis block may be short. Empty files produce just the header.

The weak checksum is the polynomial H = M^n + sum(byte[i] * M^(n-1-i)) modulo 2^32, with M = 0x08104225. The strong checksum is unkeyed BLAKE2b with output size 32, then its first strong_length bytes. It is not BLAKE2b configured to produce strong_length bytes.

API: signature(basis, block_size=2048, strong_length=32, max_blocks=1000000); parse_signature(bytes, max_blocks=1000000); Signature::block_count and Signature::to_bytes. This phase operates entirely in memory. Parsing preserves block order and bounds count before allocating records.

The format contains no record count, original length, or end marker. Removing an entire record yields another structurally valid signature; the parser cannot detect this. The record count cannot determine the original last block length. File binding and expected size must be supplied at the application layer.

Dependency: a minimal vendored correction of cc06b/mooncry 0.71.0 BLAKE2b (Apache-2.0), with license and provenance in third_party/mooncry_blake2. The exact-block finalization fix is covered by hashlib and rdiff regressions. Original polynomial-checksum code expresses the format equation; no librsync source routines were copied or translated.

## References

- [Format overview](https://librsync.github.io/page_formats.html)
- [Public magic numbers and recommended profile](https://github.com/librsync/librsync/blob/v2.3.4/src/librsync.h)
- [Opcode definitions](https://github.com/librsync/librsync/blob/v2.3.4/src/prototab.c)

These describe the format; this repository does not vendor or translate librsync implementation files.

## Automatic matcher contract

`delta(signature, target, basis_size, max_candidate_checks=1000000, max_delta_size=16777216)` accepts the validated signature object, target bytes and explicit nonnegative basis size. It verifies the expected signature block count. It cannot verify the supplied size within the last block or authenticate a signature; applications must bind metadata and result hashes.

Full windows are matched by seeded rolling polynomial and then truncated BLAKE2b-256. Short basis tails can match anywhere in the target using their own window. Candidate order is deterministic, full blocks are preferred, and consecutive basis ranges are coalesced. The comparison budget counts candidate strong-digest comparisons; exhaustion emits the remaining target bytes literally. Output size includes header and END; exceeding the explicit budget throws before further output is appended.

The signature index scales with block count. Basis offsets are Int32-bounded by caller-supplied basis size; whole target and delta are resident. This is not a network or streaming implementation, and the resulting patch is not necessarily minimal or smaller than the target. Default 32-byte strong hashes are recommended; short hashes inherit the format's collision risk.

## Incremental signature encoder

SignatureEncoder::new(block_size=2048, strong_length=32, max_blocks=1000000, max_output=67108864) returns a stateful encoder. Block size is bounded to 1..1048576. push accepts at most 65536 bytes, emits the header on its first call, then complete records. finish emits a header if necessary and the final short block. Empty pushes are permitted. Finished or failed encoders reject further calls. Budget or oversized-push failures poison the encoder, so all partial output must be discarded by the caller.

Output concatenation across any valid partition is byte-identical to the in-memory signature API. The encoder retains one block buffer and produces one bounded batch per push. Callers must drain returned batches to avoid accumulating the signature themselves. It does not enforce expected input size or authenticate data; the CLI reads its known file size, validates estimated output limits first, and writes batches to an exclusive new file. This changes only signature generation; matcher and patch APIs remain in memory.
