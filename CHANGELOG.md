# Changelog

## Unreleased (module candidate 0.1.0)

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

Not yet a Mooncakes release. API stabilization, performance improvements and registry-consumer validation remain pending.
