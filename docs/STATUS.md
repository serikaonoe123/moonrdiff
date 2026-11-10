# MoonRdiff development status

Updated 2026-11-10. Module metadata remains 0.0.1; no Mooncakes release has been published.

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Format/core | RK/BLAKE2 signatures, rdiff patch codec, full four-way interoperability | Broader adversarial/randomized and boundary evaluation |
| Incremental APIs | SignatureEncoder, DeltaEncoder, PatchDecoder with state/budget checks; Linux 128 MiB sample paths passed | Windows 128 MiB acceptance and wider resource boundaries |
| Native CLI | Windows/Linux debug/release acceptance; specific usage/format/budget diagnostics preserved in release | Input snapshot/transactional publication deliberately not promised |
| Binding | Strict optional manifest, standard BLAKE2b-256, preflight and replay checks | Distributed manifest creation and publisher authentication not provided |
| Examples | Native generated-file demonstration and independent library consumer | Validate from a public registry after publication |
| Packaging | 34-file policy; Windows/Linux archive consumers passed on JS/Native/Wasm-GC and packaged native CLI | Select release version/commit; registry acceptance after publication |
| Benchmarks | Same-runner baseline/candidate release comparison: 15 cases each, three samples per command, matching input/output hashes and budget controls | Remaining cost profiling, more independent runs and real application data |
| Release | Public source and per-milestone CI | Version review, publication authorization, registry upload and registry acceptance |

The project plan records original dates and milestone gates; historical early checkboxes are not an assertion that current features are absent. T02/T03/T04/T06 now have algorithm, version, contract and vector evidence in FORMAT.md and VALIDATION.md. Public search has not found an identical MoonBit project, but cannot establish exclusivity against unpublished work.

The planned first representative synthetic benchmark gate and controlled release comparison have passed; see BENCHMARKS.md for tested commits/runs, archived measurements and limitations. At 128 MiB, the same-profile code comparison reduced signature time about 28-30% and delta time about 37-40% for identical/modified/insert-delete cases. An observed COPY-patch timing regression was not reproduced by ten alternating pairs (both medians 0.25 s); its original cause remains unconfirmed and both results are retained. Commands remain slower than packaged rdiff, and random targets cost more bytes than full transfer. A concrete publication proposal, API review and registry acceptance are still required for the first release; the module remains unpublished.
