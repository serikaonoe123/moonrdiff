# Reproducible end-to-end CLI benchmarks

The benchmark runs on Linux with pinned MoonBit 0.10.17+d971670cd and reference rdiff 2.3.4. It measures commands, including validation/preflight and IO, rather than isolated algorithm speed. MoonRdiff delta/patch use two passes; the reference implementation has different validation behavior. Samples use a fixed order with recently accessed inputs; this is not a statistical performance ranking or network-throughput measurement.

The current workflow compares release builds of fixed pre-optimization commit `79b18247f0b30438c0474cfe80f60fd406554558` and the current commit on the same runner/compiler, with three samples per command. The original historical baseline below used the default native debug build. Build profiles and validation work differ from Ubuntu's packaged rdiff executable; timing comparisons cannot establish an isolated algorithm ranking. GNU time's hundredth-second resolution can report 0.00 for short commands.

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

The workflow runs the fixed baseline first, then the candidate, so cloud-host variation and ordering remain limitations. Its comparison script requires matching input, signature and delta hashes for all 15 cases, successful restores, all 20 default-limit controls per version and equal compiler/configuration metadata. The historical release baseline only prints opaque error constructors: its checks require the expected constructor, exit 2, empty stdout and no output file. The candidate additionally must print the specific budget reason; reports explicitly distinguish those diagnostic checks. It records regressions too, without a timing pass/fail threshold. Results from that workflow must be inspected before making code-speedup claims.

## Verified Linux baseline: 2026-11-10

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

Current signature and delta commands are substantially slower than packaged rdiff. At 128 MiB, signature took about 22 seconds and delta 31–48 seconds. Moon delta RSS peaked at 11,428 KiB in these samples and its index still scales with block count. The next performance work should establish an optimized-build baseline and profile hashing/matching before claiming improvements. This run does not establish Windows 128 MiB acceptance, multi-gigabyte support, input snapshots or transactional publication.
