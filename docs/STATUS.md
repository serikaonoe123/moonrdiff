# MoonRdiff development status

Updated 2026-11-10. Module metadata remains 0.0.1; no Mooncakes release has been published.

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Format/core | RK/BLAKE2 signatures, rdiff patch codec, full four-way interoperability | Broader adversarial/randomized and boundary evaluation |
| Incremental APIs | SignatureEncoder, DeltaEncoder, PatchDecoder with state/budget checks | Large-file/resource acceptance and representative performance |
| Native CLI | Windows/Linux signature/delta/patch/verify/manifest | Input snapshot/transactional publication deliberately not promised |
| Binding | Strict optional manifest, standard BLAKE2b-256, preflight and replay checks | Distributed manifest creation and publisher authentication not provided |
| Examples | Native generated-file demonstration and independent library consumer | Validate from a public registry after publication |
| Packaging | 34-file policy, actual archive extraction and consumer workflow | Complete full-platform candidate run; select release version/commit |
| Benchmarks | 4/32 MiB synthetic RSS and elapsed measurements | Planned 1/16/128 MiB workloads including random/compressed data, total exchange cost and comparisons |
| Release | Public source and per-milestone CI | Version review, publication authorization, registry upload and registry acceptance |

The project plan records original dates and milestone gates; historical early checkboxes are not an assertion that current features are absent. T02/T03/T04/T06 now have algorithm, version, contract and vector evidence in FORMAT.md and VALIDATION.md. Public search has not found an identical MoonBit project, but cannot establish exclusivity against unpublished work.

Current consumer packaging work does not make the first release complete. Prioritize full candidate verification, benchmark/limit documentation, and a concrete publication proposal before claiming release readiness.
