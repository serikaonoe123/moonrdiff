# MoonRdiff development status

Updated 2026-11-28. Mooncakes 0.1.5 is published from 14b4e00. Windows and Linux verified the registry package and built its native CLI using MoonBit 1.0 RC1. [Release record](RELEASE-0.1.5.md)

The walkthrough covers a fresh registry consumer, bound file restore, and the resource-cache application. Its compatibility table points to the platform reports. [Acceptance guide](ACCEPTANCE.md)

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Format/core | RK/BLAKE2 signatures, rdiff patch codec, full four-way interoperability | Broader adversarial/randomized and boundary evaluation |
| Incremental APIs | SignatureEncoder, DeltaEncoder, PatchDecoder with state/budget checks; Windows/Linux release 128 MiB sample paths passed; new 38-case partitioned-pipeline and exact-budget regression passed all three backends on both platforms in CI 42963384904 (4013e9c) | Wider resource boundaries and larger real application inputs |
| Native CLI | Published 0.1.4 preserves the OS diagnostic after a short read. CI covers capacity and sync errors, interruption and retry behavior. | Physical media failures and recovery after power loss |
| Binding | Strict optional manifest, standard BLAKE2b-256, preflight/replay checks; both native platforms passed 128 MiB modified-file bound restore | Distributed manifest creation and publisher authentication not provided |
| Examples | Both original user-facing demos run in MoonBit without Python; TAR/ZIP/TAR.GZ explicit-date backend passed Windows/Linux CI 44264366022 after correcting abbreviated-time parsing | External application integrations and broader real application data; continue evaluating Python development-tool migrations |
| Resource-cache consumer | Registry 0.1.3, 34 installed files verified. The optional Lua 5.4.7 → 5.4.8 acceptance extends the suite to five exact restores and 42 rejection controls on each of Windows and Linux, including both official gzip and decoded TAR fixtures in CI [44688437344](https://github.com/serikaonoe123/moonrdiff/actions/runs/44688437344). | Production cache durability |
| Development tooling | Native CLI acceptance runs in MoonBit with a small independent Python hashlib/struct oracle; Windows debug/release each passed 125 checks and Linux each passed 126 with default links, in CI 44055861932 | Other Python development tools remain; 128 MiB CI 44055861763 passed after isolating negative-control output paths |
| Check entry point | MoonBit cmd/check on Node22 preserves all 14 ordered steps; default Windows/Linux CI 44081050069 passed with links enabled and independent oracles retained | Other Python packaging/reference/benchmark tools remain |
| Packaging | The published 0.1.5 archive and both registry consumers match the approved 34-file inventory. | Preserve inventories for future versions |
| Benchmarks | Same-runner baseline/candidate release comparison: 15 cases each, three samples per command, matching input/output hashes and budget controls | Remaining cost profiling, more independent runs and real application data |
| Release | Versions 0.1.0 through 0.1.5 were published and verified from the registry. | D8050 appeared in both shells in the same diagnostic context. A fresh build passed in normal local PowerShell. Root cause remains unconfirmed. See NATIVE-WINDOWS-DIAGNOSTIC.md. |

The default registry workflow and the basic consumer use 0.1.5. The resource-cache application and historical walkthrough use the fixed 0.1.3 baseline. [0.1.3 release record](RELEASE-0.1.3.md) · [Resource-cache inputs](RESOURCE-CACHE.md)

Benchmark schema-3 path isolation passed controlled run 44082843263: both versions passed 15 cases and 20 distinct-path budget controls. Eight report-copy compatibility/rejection checks passed. This updates acceptance stability, not algorithm performance.

The project plan records original dates and milestone gates; historical early checkboxes are not an assertion that current features are absent. T02/T03/T04/T06 now have algorithm, version, contract and vector evidence in FORMAT.md and VALIDATION.md. Public search has not found an identical MoonBit project, but cannot establish exclusivity against unpublished work.

The planned first representative synthetic benchmark gate and controlled release comparisons have passed; see BENCHMARKS.md for tested commits/runs, archived measurements and limitations. LARGE-FILES.md records the separate five-case Windows/Linux 128 MiB gate, including default-budget refusals and a modified-file bound restore. The latest same-release prefilter comparison reduced 128 MiB random delta time 8.74 -> 3.80 s (56.5%) and compressed 3.75 -> 2.70 s (28%). Input and output hashes are unchanged; the extra hint table is capped at 64 KiB. Favorable cases were mixed, and unmodified-stage timing anomalies remain recorded rather than discarded. The earlier COPY-patch anomaly was not reproduced in its ten-pair follow-up. Commands remain slower than packaged rdiff, and random targets cost more bytes than full transfer. API review, the approved first upload and registry acceptance are complete. The module is published; local Native recovery and the unconfirmed historical D8050 cause are documented in NATIVE-WINDOWS-DIAGNOSTIC.md, and the README wording correction is recorded in RELEASE-0.1.1.md.
