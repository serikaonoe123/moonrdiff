# Changelog

## Unreleased

- Extend the source-update example with TAR.GZ and verified full-file delivery when its complete file/identity cost is lower. Report offline planning, signature reuse and already-sent signature costs separately.

- Add a reproducible source-bundle update example using two committed project snapshots, TAR/ZIP inputs, separated sender/receiver directories, bound restores and file-byte transfer accounting; run it on Windows/Linux CI.

- Record successful local Native revalidation of the original failed consumer, 27 root tests and a fresh complete archive/CLI acceptance. Historical D8050 is not currently reproduced; no targeted fix or root cause is claimed.
- Add a 38-case deterministic edit corpus covering the complete incremental signature/delta/patch pipeline under two push partitions, including empty pushes, repeated data, short tails and 64 KiB boundaries.
- Check exact signature/target/patch-output budgets and delta limits; nine literal sizes accept the exact delta budget and reject one byte less with the public error type.
- Correct the repository README's installation dependency to the published 0.1.1 version. No public API or production algorithm changes.

## 0.1.1 — 2026-11-11

- Remove the package README's stale prepublication wording; keep publication status in per-version release records.
- Correct a stale API-review status paragraph. No public API, algorithm, budget or native compiler setting changes.
- Bind registry checks to the version in the selected approved inventory, so testing released 0.1.0 remains independent of a newer candidate's example dependency.
- Add a read-only local D8050 diagnostic record without claiming a fix or changing security settings.
- Published from 9ed7e11; Windows/Linux registry consumers verified the approved 34-file contents and passed five groups on each backend. See docs/RELEASE-0.1.1.md.

## 0.1.0 — 2026-11-11

- Windows/Linux release CLI 128 MiB acceptance: five fixture types, default-budget rejection, and independent manifest/bound-restore/verify checks for the modified case.

- Bounded streamed full-block lookup prefilter; same-release Linux comparison reduces the sampled 128 MiB random delta time from 8.74 to 3.80 s while preserving exact patch bytes. Reports retain small regressions/timing anomalies and table-memory cost.

- RK/BLAKE2 signatures and rdiff-compatible delta encoding/decoding.
- Incremental signature generation, delta matching and patch parsing with explicit resource/lifecycle checks.
- Windows/Linux native file CLI with exclusive outputs and bounded processing.
- Optional strict BLAKE2b-256 file binding manifests.
- Corrected exact-block BLAKE2 finalization in an attributed minimal Apache-2.0 adaptation.
- Independent rdiff interoperability, file controls, synthetic memory measurements and archive-consumer acceptance workflow.
- Verified Linux 1/16/128 MiB representative synthetic workloads, transfer costs, per-command time/RSS and default-budget rejection controls; archived report includes slow paths and random-data overhead.
- Reuse bounded BLAKE2 compression workspaces/local lanes and reduce ring-index arithmetic; add same-runner release comparisons and full release CLI acceptance alongside debug CI.
- Preserve usage/format/budget error messages in release CLI builds through explicit diagnostic formatting.

Published to Mooncakes from e09db0b with the approved 34-file inventory. Windows/Linux registry consumers verified all installed source hashes and passed five public tests on JS, Native and Wasm-GC. See docs/RELEASE-0.1.0.md for publication details and retained local Native/compiler and package-README limitations.
