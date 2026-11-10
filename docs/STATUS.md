# MoonRdiff development status

Updated 2026-11-10. Module metadata remains 0.0.1; no Mooncakes release has been published.

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Format/core | RK/BLAKE2 signatures, rdiff patch codec, full four-way interoperability | Broader adversarial/randomized and boundary evaluation |
| Incremental APIs | SignatureEncoder, DeltaEncoder, PatchDecoder with state/budget checks; Linux 128 MiB sample paths passed | Windows 128 MiB acceptance and wider resource boundaries |
| Native CLI | Windows/Linux signature/delta/patch/verify/manifest | Input snapshot/transactional publication deliberately not promised |
| Binding | Strict optional manifest, standard BLAKE2b-256, preflight and replay checks | Distributed manifest creation and publisher authentication not provided |
| Examples | Native generated-file demonstration and independent library consumer | Validate from a public registry after publication |
| Packaging | 34-file policy; Windows/Linux archive consumers passed on JS/Native/Wasm-GC and packaged native CLI | Select release version/commit; registry acceptance after publication |
| Benchmarks | All 15 Linux 1/16/128 MiB workloads and 20 default-budget controls passed; byte costs, time and RSS compared with rdiff | Optimized-build baseline/profiling; repeated samples and real application data |
| Release | Public source and per-milestone CI | Version review, publication authorization, registry upload and registry acceptance |

The project plan records original dates and milestone gates; historical early checkboxes are not an assertion that current features are absent. T02/T03/T04/T06 now have algorithm, version, contract and vector evidence in FORMAT.md and VALIDATION.md. Public search has not found an identical MoonBit project, but cannot establish exclusivity against unpublished work.

The planned first representative synthetic benchmark gate has passed; see BENCHMARKS.md for the tested commit/run, archived measurements and limitations. Signature/delta time remains substantially slower than packaged rdiff, and random targets cost more bytes than full transfer. A concrete publication proposal, API review and registry acceptance are still required for the first release; the module remains unpublished.
