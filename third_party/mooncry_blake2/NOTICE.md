# Third-party attribution

Source: cc06b/mooncry 0.71.0, lib/blake2.mbt.
Repository: https://github.com/cc06b/mooncry
Registry: https://mooncakes.io/docs/cc06b/mooncry@0.71.0
License: Apache-2.0; the full upstream LICENSE is retained beside this file.
Original source SHA-256: 4d906a18a33e11cb5d97e2d8c0590a3eba7ba3aa8df71d34b7b6abe10a8205e5

Adaptations by MoonRdiff on 2026-11-10:
- Keep the last full 128-byte block for final compression; use subtraction in the loop condition to avoid index overflow.
- Supply a standalone UInt64 rotate helper so no unrelated crypto code is bundled.
- Add provenance comments and MoonBit formatting. No other algorithms are included.
- Added an Apache-2.0 incremental BLAKE2b-256 adapter using the same compression core, with bounded pushes, final-block retention and Python hashlib regression vectors. The adapter is original MoonRdiff code; the attributed compression implementation is retained.
- Performance adaptation: fixed-size UInt64 state/message/work arrays, local G-function lanes, and per-hash/context reuse of message and compression workspace. Algorithm parameters, round order and final-block handling are unchanged.

This directory retains Apache-2.0 licensing. The repository's MIT license applies to MoonRdiff's original code, not to these third-party files. The registry package was only used to obtain and test the source; no runtime registry dependency remains.
