# Format and API contract

The root package provides in-memory and incremental signature, delta and patch APIs. Native file commands also support an optional separate binding manifest. This document distinguishes those interfaces; the raw rdiff formats remain unchanged.

## Supported delta data

- Magic: `0x72730236`, big-endian.
- Decode: END 0x00; short literals 0x01–0x40; length-prefixed literals 0x41–0x44; basis COPY 0x45–0x54.
- Parameter widths: 1, 2, 4, 8 bytes; big-endian unsigned representation.
- In-memory API rejects parameter values above 2,147,483,647 before conversion. Also rejects reserved opcodes, missing END, trailing bytes, truncated parameters/data, out-of-basis copies and output beyond caller budget.
- Encode: short literals up to 64 bytes, 4-byte lengths for longer literals, 4-byte offset/length COPY, final END. Empty literals are omitted. Encoder has no basis input and cannot validate COPY against its size; decoder performs that validation.
- The in-memory patch convenience function holds supplied basis/delta and reconstructed output. PatchDecoder provides incremental parsing separately, as described below.
- Copy addresses the old basis, never the output under construction.
- Raw deltas do not authenticate the basis or result. The caller must bind them to the correct files. Native commands can use the optional separate [binding manifest](BINDING.md); it does not alter raw delta bytes or authenticate a publisher.
- encode takes explicit in-memory instructions with no output-budget parameter; callers control their sizes and allocation cost. It cannot validate COPY against a basis. Use the budgeted delta encoders for automatic matching and PatchDecoder for an explicit instruction-count limit.

## Supported signature profile

`RS_RK_BLAKE2_SIG_MAGIC` (0x72730147) only. Header has positive Int32 block size and strong length 1..32. Each record contains a 32-bit unsigned weak checksum followed by the truncated strong digest. The last basis block may be short. Empty files produce just the header.

The weak checksum is the polynomial H = M^n + sum(byte[i] * M^(n-1-i)) modulo 2^32, with M = 0x08104225. The strong checksum is unkeyed BLAKE2b with output size 32, then its first strong_length bytes. It is not BLAKE2b configured to produce strong_length bytes.

In-memory API: signature(basis, block_size=2048, strong_length=32, max_blocks=1000000); parse_signature(bytes, max_blocks=1000000); Signature::block_count and Signature::to_bytes. Parsing preserves block order and bounds count before allocating records. Incremental generation is provided separately by SignatureEncoder.

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

Output concatenation across any valid partition is byte-identical to the in-memory signature API. The encoder retains one block buffer and produces one bounded batch per push. Callers must drain returned batches to avoid accumulating the signature themselves. It does not enforce expected input size or authenticate data; the CLI reads its known file size, validates estimated output limits first, and writes batches to an exclusive new file. Incremental matcher and patch interfaces are described below; their in-memory convenience functions remain available.

## Incremental patch decoder

PatchDecoder::new(basis_size, max_output, max_instructions=1000000) exposes push(BytesView) -> Array[Instruction] and finish() -> Unit. A push accepts at most 65536 bytes. Literal instructions contain only the current fragment, while COPY requests address the old basis and may be larger; callers must serve these using bounded reads. The parser retains at most 16 parameter/header bytes and counters. Callers drain each returned batch; retaining all batches defeats bounded buffering.

All standard opcode widths are accepted within the Int32 parameter limit. Output budget is reserved when each instruction is parsed, and copy bounds are checked against supplied basis size. Reserved opcodes, excess instructions, overflows and data after END fail closed. Missing END, unfinished parameters or literal bodies fail at finish. Any failed push/finish poisons the decoder; finished instances cannot be reused. Output emitted before a later error is provisional and must not be treated as a validated complete result.

The CLI validates a first full bounded pass before creating output and replays in a second bounded pass. This keeps format/budget failures from creating files but does not snapshot changing inputs or guarantee atomic output publication. The in-memory patch function remains available independently.

## Incremental delta encoder

DeltaEncoder::new(signature, basis_size, max_candidate_checks=1000000, max_delta_size=16777216, max_target_size=67108864) accepts the existing validated signature and explicit basis metadata. Block size is capped at 1 MiB and pushes at 64 KiB. It indexes full blocks once per encoder, maintains a ring lookahead for one block, and rolls full/tail checksums across pushes. EOF drains shorter windows, including relocated short basis tails. Full-block matches retain priority.

push returns newly encoded bytes; finish emits the remaining literal/COPY and END. Literal accumulation is capped at 64 KiB and COPY coalescing persists across pushes. Identical input/configuration produces identical bytes regardless of push partition; long literal layout may differ from the in-memory encoder. Comparison budget exhaustion uses literal fallback for the rest of the entire stream. Input/output budgets are cumulative. Failed or finished encoders cannot be resumed. Caller must discard provisional output on error.

The target and delta need not be retained, but the signature plus index scale with basis block count. Clients must drain batches. The native delta command runs two bounded passes so output-budget failures happen before file creation, still requiring stable target data and no transactional or authentication guarantee.

The streamed full-block index uses a 256-byte to 64-KiB membership hint. Positive hints still require complete weak-key and strong-digest checks. This bounded table does not bound total signature/index/process memory, and does not change comparison-budget accounting or short-tail semantics.

## Public defaults and lifecycle

| Interface | Defaults or required budgets |
| --- | --- |
| signature | block_size=2048, strong_length=32, max_blocks=1000000 |
| parse_signature | max_blocks=1000000; parsed block size may exceed incremental encoders' 1 MiB cap |
| encode | No explicit byte/count budget; caller-owned in-memory instructions |
| delta | basis_size required; max_candidate_checks=1000000, max_delta_size=16777216 |
| patch | max_output required; use PatchDecoder if an explicit instruction-count cap is needed |
| SignatureEncoder::new | block_size=2048, strong_length=32, max_blocks=1000000, max_output=67108864 |
| DeltaEncoder::new | basis_size required; max_candidate_checks=1000000, max_delta_size=16777216, max_target_size=67108864 |
| PatchDecoder::new | basis_size/max_output required; max_instructions=1000000 |

All three incremental objects accept pushes of at most 65536 bytes. Empty pushes are allowed while open. A successful finish closes the instance; any failed push/finish permanently fails it. Further calls raise DeltaError::Invalid(String). Instances own mutable state; aliases share that state. Consumers must discard provisional outputs after errors, and must call finish at EOF even after receiving useful batches or an END opcode.

SignatureEncoder::output_bytes starts at zero, includes the header once emitted and includes complete records. buffered_bytes counts the pending partial block, not all input received. Counters after a failure are diagnostic only, not a resumable checkpoint.

Public root failures use DeltaError::Invalid(String); messages are human diagnostics, not stable error identifiers. Catch the public error variant rather than matching exact text. Chunk-partition independence is part of the incremental contract. Exact automatic patch layout across future versions is not a canonical-format guarantee; compatible generators may choose different valid instructions. Byte-identical version comparisons in the benchmark describe those tested commits.
