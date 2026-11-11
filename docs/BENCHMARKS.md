# Reproducible end-to-end CLI benchmarks

The benchmark runs on Linux with pinned MoonBit 0.10.17+d971670cd and reference rdiff 2.3.4. It measures commands, including validation/preflight and IO, rather than isolated algorithm speed. MoonRdiff delta/patch use two passes; the reference implementation has different validation behavior. Samples use a fixed order with recently accessed inputs; this is not a statistical performance ranking or network-throughput measurement.

The current workflow compares release builds of the previous optimization milestone `c439ae9dc7631fd627842b73222cbc1b6470133a` and the current commit on the same runner/compiler, with three samples per command. Historical runs below name their own fixed baselines. The original baseline used the default native debug build. Build profiles and validation work differ from Ubuntu's packaged rdiff executable; timing comparisons cannot establish an isolated algorithm ranking. GNU time's hundredth-second resolution can report 0.00 for short commands.

```sh
moon update
moon build cmd/moonrdiff --target native --release --deny-warn
python scripts/benchmark.py --profile release --repetitions 3
```

GNU time and rdiff must be installed. Windows can verify only data generation with `python scripts/benchmark.py --sizes 1 --generate-only`; that mode records no performance results.

## Workloads and measurements

Nominal sizes are 1, 16 and 128 MiB, each with five cases:

- identical: byte-identical old and new files;
- modified: replace 4096 middle bytes;
- insert-delete: insert 4096 bytes and remove 4096 original bytes;
- random: independently seeded pseudorandom old and new files;
- compressed: gzip the seeded pseudorandom stream before/after a 4096-byte middle replacement, with fixed gzip metadata. Compressed file byte size can exceed nominal raw size.

Generation uses Python Random(seed=20261110), 64 KiB chunks, with separate seed 20261111 for unrelated random targets. Report includes Python/OS/CPU, file SHA-256 hashes, actual byte sizes and configuration. Reproducing compressed bytes also depends on the Python/zlib environment; compare regenerated hashes before treating them as the same fixtures. Block size is 4096 and strong length 32 for both tools. Signatures are compared byte-for-byte; each tool's restored output must match the independent target SHA-256.

GNU time records peak RSS in KiB and elapsed seconds separately for signature/delta/patch. The harness also records wall time. Schema v2 preserves all samples and summarizes median elapsed/wall time and maximum RSS. Each repetition writes a new file and its SHA-256 must match the first sample outside the timed interval. Default standalone settings remain `--profile debug --repetitions 1`; use the flags above for the release protocol. First exchange is signature bytes + delta bytes; reused-signature exchange is delta bytes. Full-transfer baseline is target file bytes, not measured network latency. Manifest metadata, authentication and transport overhead are outside this raw-format byte comparison.

The 128 MiB tier explicitly raises CLI budgets to 512 MiB. Each case then confirms that default signature, delta and patch input limits reject these files without creating output, and that patch still rejects output beyond 64 MiB when only its input budget is raised. This proves those Linux sample paths, not general support for multi-gigabyte files or Windows large-file behavior.

The script saves per-case progress after correctness checks and preserves failed-case data on the runner. The benchmark workflow uploads reports, command logs, hardware and tool records, not redundant large generated files. Inputs can be reconstructed with the committed generator and hashes. Archive/package inventory remains unchanged.

The workflow runs the fixed baseline first, then the candidate, so cloud-host variation and ordering remain limitations. Its comparison script requires matching input, signature and delta hashes for all 15 cases, successful restores, all 20 default-limit controls per version and equal compiler/configuration metadata. Both current versions must emit the specific budget reason, exit 2, empty stdout and no output file. Only the older 79b1824 release baseline in historical runs uses explicitly recorded opaque-constructor checks. The comparison records regressions too, without a timing pass/fail threshold. Results from each workflow must be inspected before making code-speedup claims.

## Verified streamed-lookup prefilter: 2026-11-11

[Run 42949042760](https://github.com/serikaonoe123/moonrdiff/actions/runs/42949042760) compared previous milestone `c439ae9dc7631fd627842b73222cbc1b6470133a` with `150ce03a2e0ffb94568c4e6f1734c6170c712fcd`, both release builds on one Intel Xeon 6973P-C VM with 4 logical CPUs. Python was 3.12.16; compiler/reference versions remain pinned above. Each version passed 15 cases with three samples per command and 20 specific-reason budget controls. All input/signature/delta hashes matched across versions. Downloaded artifact records were checked against all 30 official log entries.

The streamed matcher now rejects impossible full-block map lookups with a per-encoder membership hint. The table has 64-16384 UInt32 slots (256 bytes-64 KiB of table storage). Hint collisions still require the complete weak-key lookup and strong digest check; short-tail handling and candidate/output budgets are unchanged. This is a bounded memory tradeoff, not a process-RSS bound or authentication mechanism.

128 MiB nominal delta medians, seconds, three samples:

| Case | Previous release | Prefilter release | Time change |
| --- | ---: | ---: | --- |
| identical | 1.88 | 1.76 | 6.4% lower |
| modified | 1.98 | 1.77 | 10.6% lower |
| insert-delete | 1.76 | 1.77 | 0.6% higher |
| random | 8.74 | 3.80 | 56.5% lower |
| compressed | 3.75 | 2.70 | 28.0% lower |

At 16 MiB, random delta time was 0.91 -> 0.56 s and compressed 0.41 -> 0.28 s. Favorable cases were mixed: identical 0.23 -> 0.22, modified 0.22 -> 0.22, insert-delete 0.22 -> 0.23 s. All patch byte costs are unchanged; an unrelated random target still produces a larger first exchange than full transfer. No automatic transport selection was added.

Unmodified stages also fluctuated: 16 MiB random signature was 0.11 -> 0.29 s, 16 MiB insert-delete patch was 0.10 -> 0.29 s, and 1 MiB identical signature was 0.00 -> 0.11 s. Their cause is unconfirmed; the original samples remain public and no end-to-end improvement for every workload is claimed. GNU time resolution and fixed-order shared-runner behavior limit small ratios. Do not compare absolute times against the previous AMD-runner milestone to attribute this change; use the paired versions within this run.

Candidate 128 MiB delta RSS maxima were 9992-10852 KiB across cases, versus 9764-10916 KiB baseline. Those observations do not establish a memory reduction. Immutable reports retain all measurements and unfavorable cases:

- [Previous milestone report](../benchmarks/prefilter-2026-11-11/baseline.json), SHA-256 `5b5629964cf1a164220589f15d164957b7b851a007056abf51e92685b7230780`.
- [Prefilter candidate report](../benchmarks/prefilter-2026-11-11/candidate.json), SHA-256 `6bdb036f2ac917a0acd513c1712b27df4aaab7c9280a7751504c07a7a2ae227f`.
- [Computed comparison](../benchmarks/prefilter-2026-11-11/comparison.json), SHA-256 `eff441b1d385bae9d5cb802fe43c7af3f022e3667b1220db3ded2f91634ffe15`.

## Verified release optimization: 2026-11-10

[Run 42786913585](https://github.com/serikaonoe123/moonrdiff/actions/runs/42786913585) compared fixed baseline `79b18247f0b30438c0474cfe80f60fd406554558` with optimized `0ebe8a406f54954c514d0050f129b9af9d32bd87`, both **release** builds. All 15 cases per version passed with three samples per command. All input, signature and delta hashes matched between versions; both tools' repeated restores were verified. Both versions passed 20 default-budget controls, with the historical/candidate diagnostic distinction described above. Downloaded artifacts were matched against all 30 official log records.

Environment: Ubuntu 24.04, AMD EPYC 7763 VM with 4 logical CPUs, Python 3.12.16, zlib 1.3, pinned MoonBit and rdiff versions above. This compares the combined code changes under one build profile, separately from the benefit of selecting release instead of debug.

128 MiB nominal cases; times are medians of three in seconds. Reductions describe this measured run, with no confidence intervals:

| Case | Signature before -> after | Time reduction | Delta before -> after | Time reduction |
| --- | --- | ---: | --- | ---: |
| identical | 1.75 -> 1.23 | 29.7% | 4.98 -> 3.10 | 37.8% |
| modified | 1.76 -> 1.24 | 29.5% | 4.98 -> 3.13 | 37.1% |
| insert-delete | 1.76 -> 1.26 | 28.4% | 5.14 -> 3.09 | 39.9% |
| random | 1.78 -> 1.26 | 29.2% | 13.65 -> 12.39 | 9.2% |
| compressed | 1.78 -> 1.24 | 30.3% | 7.52 -> 5.89 | 21.7% |

The changes keep BLAKE2 G lanes in locals, reuse bounded per-hash/context fixed arrays, and replace ring-index remainders with bounded wraps. Public APIs, digest parameters, patch bytes, candidate budgets and two-pass preflight remain unchanged. At 128 MiB, candidate delta peak RSS ranged from 9888 to 10916 KiB across these cases; index memory still scales with block count. These are not demonstrated memory reductions.

Patch was not the optimization target and its results are retained: 128 MiB medians before -> after were identical 0.24 -> 0.68, modified 0.24 -> 0.26, insert-delete 0.24 -> 0.24, random 0.42 -> 0.44, compressed 0.58 -> 0.61 s. The candidate identical case's three samples were 0.68, 1.11 and 0.25 s. This observed regression prompted the separate follow-up below. Small 1 MiB timers also have insufficient resolution for precise ratios.

[Follow-up run 42788339513](https://github.com/serikaonoe123/moonrdiff/actions/runs/42788339513) measured only that 128 MiB COPY case after one untimed warmup per version, using ten alternating AB/BA pairs with fresh outputs and independent restore hashes. Baseline and candidate median elapsed times were both **0.25 s**, ranges 0.22-0.26 and 0.23-0.26 s. Median user/system CPU times were 0.01/0.18 s baseline and 0.015/0.175 s candidate. All 20 measured restores and two warmups passed. Candidate commit `5e4deb004640b4449600f1b6a65cac28777bc6b1` adds only the follow-up harness/workflow after the measured optimization; its MoonBit source is unchanged from `0ebe8a4`.

The follow-up did not reproduce a systematic COPY-patch regression. It does not establish why the original slow samples occurred, nor prove that all patch cases improve. Both the original result and this follow-up remain public. Reproduce the follow-up by building the two release checkouts, then running `python scripts/measure_patch_comparison.py --baseline-root PATH_TO_BASELINE` from the current repository on Linux with GNU time.

Complete immutable snapshots retain every sample, all reference timings/RSS, hashes and unfavorable cases:

- [Baseline release report](../benchmarks/release-2026-11-10/baseline.json), SHA-256 `827053a26b15fd5474cc2d74d24891c30bb518f4910ef386ba4bbcb934d00c18`.
- [Candidate release report](../benchmarks/release-2026-11-10/candidate.json), SHA-256 `60de0cb0d4154da326600ee272f93bfa70d2f97c3c2ee41ea2074074bd5fa742`.
- [Computed comparison](../benchmarks/release-2026-11-10/comparison.json), SHA-256 `720c49f8827d45cc637d7150cd773273878a7d8e02f4b1ca0f8ba961ae456c21`.
- [Alternating COPY-patch follow-up](../benchmarks/release-2026-11-10/patch-followup.json), SHA-256 `fd3cc3b03533161dadb19cccfd6183ce886607e85891052da38353b6ec4e4044`.

The optimized release commands remain slower than packaged rdiff, whose validation/sync work differs. Random targets still increase transmission bytes. More independent runs, application data and profiling remain useful; these results do not claim a universal speedup or multi-gigabyte support. The separate Windows/Linux 128 MiB correctness gate is now documented in [LARGE-FILES.md](LARGE-FILES.md); it is not a Windows performance comparison.

## Historical default-debug baseline: 2026-11-10

Tested commit: `79b18247f0b30438c0474cfe80f60fd406554558`. [Benchmark run 42782560355](https://github.com/serikaonoe123/moonrdiff/actions/runs/42782560355) passed all 15 cases and 20 negative default-budget checks. The downloaded report's records were compared with all 15 official `BENCH_RESULT` log entries. The [unchanged machine-readable report](../benchmarks/2026-11-10-linux.json) preserves hashes, exact byte counts and all six processes' metrics for every size/scenario; SHA-256: `37d8bc9e995cf23d101e0f3389b70148cf80ab4166f069ad4ec0d75451745229`.

Runner: Ubuntu 24.04, AMD EPYC 7763 virtual machine with 4 logical CPUs; Python 3.12.16, GNU time 1.9, rdiff package 2.3.4-1.1ubuntu2. This is a single run on shared cloud hardware, with the debug/packaged-binary differences described above.

128 MiB nominal tier (all sizes below are bytes):

| Case | Target/full transfer | Signature | Moon delta only | Moon first exchange | First/full |
| --- | ---: | ---: | ---: | ---: | ---: |
| identical | 134,217,728 | 1,179,660 | 14 | 1,179,674 | 0.8789% |
| modified | 134,217,728 | 1,179,660 | 4,124 | 1,183,784 | 0.8820% |
| insert-delete | 134,217,728 | 1,179,660 | 8,220 | 1,187,880 | 0.8850% |
| random | 134,217,728 | 1,179,660 | 134,227,973 | 135,407,633 | 100.8865% |
| compressed | 134,254,658 | 1,180,056 | 33,554,492 | 34,734,548 | 25.8721% |

For the same tier, triplets are **signature / delta / patch**. Times are seconds; memory is KiB. Reference RSS for each case is retained in the JSON report.

| Case | Moon elapsed | rdiff elapsed | Moon peak RSS |
| --- | --- | --- | --- |
| identical | 22.42 / 47.65 / 0.23 | 0.27 / 0.31 / 0.09 | 3620 / 10536 / 3556 |
| modified | 22.55 / 47.70 / 0.27 | 0.27 / 0.31 / 0.09 | 3616 / 10356 / 3700 |
| insert-delete | 22.61 / 47.53 / 0.27 | 0.27 / 0.31 / 0.09 | 3620 / 10428 / 3556 |
| random | 22.28 / 31.28 / 0.48 | 0.27 / 2.59 / 0.11 | 3620 / 11428 / 4292 |
| compressed | 22.28 / 45.19 / 0.62 | 0.27 / 0.87 / 0.08 | 3556 / 10844 / 4324 |

Local changes saved transfer bytes in these fixtures. Independent random targets made the first exchange about 0.89% larger than full transfer at all three sizes, so callers should support choosing full transfer when a delta is uneconomic. No automatic transport selection is implemented. The compressed fixture uses gzip over pseudorandom bytes; its result does not characterize arbitrary archives, media or a real application corpus.

In that initial debug run, signature took about 22 seconds and delta 31–48 seconds at 128 MiB. Moon delta RSS peaked at 11,428 KiB and its index still scales with block count. These measurements motivated the controlled release comparison above; comparing different runs/build profiles does not isolate a code-change speedup. This run does not establish Windows 128 MiB acceptance, multi-gigabyte support, input snapshots or transactional publication.
