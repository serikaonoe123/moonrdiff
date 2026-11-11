# MoonRdiff development status

Updated 2026-11-11. Mooncakes 0.1.1 documentation patch is published from 9ed7e11; Windows/Linux registry acceptance passed. See RELEASE-0.1.1.md; original 0.1.0 evidence remains retained.

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Format/core | RK/BLAKE2 signatures, rdiff patch codec, full four-way interoperability | Broader adversarial/randomized and boundary evaluation |
| Incremental APIs | SignatureEncoder, DeltaEncoder, PatchDecoder with state/budget checks; Windows/Linux release 128 MiB sample paths passed; new 38-case partitioned-pipeline and exact-budget regression passed all three backends on both platforms in CI 42963384904 (4013e9c) | Wider resource boundaries and larger real application inputs |
| Native CLI | Windows/Linux debug/release acceptance; specific usage/format/budget diagnostics preserved in release | Input snapshot/transactional publication deliberately not promised |
| Binding | Strict optional manifest, standard BLAKE2b-256, preflight/replay checks; both native platforms passed 128 MiB modified-file bound restore | Distributed manifest creation and publisher authentication not provided |
| Examples | Native generated-file demo and fresh registry consumers: five public tests per backend on both platforms | Broader application integrations |
| Packaging | Published 0.1.1: approved 34-file content matches registry installation; both platforms and all consumer backends passed | Preserve inventories for future versions |
| Benchmarks | Same-runner baseline/candidate release comparison: 15 cases each, three samples per command, matching input/output hashes and budget controls | Remaining cost profiling, more independent runs and real application data |
| Release | User-approved 0.1.0 and 0.1.1 published/registry-verified; stale package README corrected in 0.1.1 | D8050 cause remains unconfirmed after read-only inspection |

The project plan records original dates and milestone gates; historical early checkboxes are not an assertion that current features are absent. T02/T03/T04/T06 now have algorithm, version, contract and vector evidence in FORMAT.md and VALIDATION.md. Public search has not found an identical MoonBit project, but cannot establish exclusivity against unpublished work.

The planned first representative synthetic benchmark gate and controlled release comparisons have passed; see BENCHMARKS.md for tested commits/runs, archived measurements and limitations. LARGE-FILES.md records the separate five-case Windows/Linux 128 MiB gate, including default-budget refusals and a modified-file bound restore. The latest same-release prefilter comparison reduced 128 MiB random delta time 8.74 -> 3.80 s (56.5%) and compressed 3.75 -> 2.70 s (28%). Input and output hashes are unchanged; the extra hint table is capped at 64 KiB. Favorable cases were mixed, and unmodified-stage timing anomalies remain recorded rather than discarded. The earlier COPY-patch anomaly was not reproduced in its ten-pair follow-up. Commands remain slower than packaged rdiff, and random targets cost more bytes than full transfer. API review, the approved first upload and registry acceptance are complete. The module is published; the local MSVC limitation remains documented in NATIVE-WINDOWS-DIAGNOSTIC.md, and the README wording correction is recorded in RELEASE-0.1.1.md.
