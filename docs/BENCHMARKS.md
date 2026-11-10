# Reproducible end-to-end CLI benchmarks

The benchmark runs on Linux with pinned MoonBit 0.10.17+d971670cd and reference rdiff 2.3.4. It measures commands, including validation/preflight and IO, rather than isolated algorithm speed. MoonRdiff delta/patch use two passes; the reference implementation has different validation behavior. Results are one warm-cache sample per workload in fixed order, not a statistical performance ranking or network-throughput measurement.

```sh
moon update
moon build cmd/moonrdiff --target native --deny-warn
python scripts/benchmark.py
```

GNU time and rdiff must be installed. Windows can verify only data generation with `python scripts/benchmark.py --sizes 1 --generate-only`; that mode records no performance results.

## Workloads and measurements

Nominal sizes are 1, 16 and 128 MiB, each with five cases:

- identical: byte-identical old and new files;
- modified: replace 4096 middle bytes;
- insert-delete: insert 4096 bytes and remove 4096 original bytes;
- random: independently seeded pseudorandom old and new files;
- compressed: gzip the seeded pseudorandom stream before/after a 4096-byte middle replacement, with fixed gzip metadata. Compressed file byte size can exceed nominal raw size.

Generation uses Python Random(seed=20261110), 64 KiB chunks, with separate seed 20261111 for unrelated random targets. Report includes Python/OS/CPU, file SHA-256 hashes, actual byte sizes and configuration. Block size is 4096 and strong length 32 for both tools. Signatures are compared byte-for-byte; each tool's restored output must match the independent target SHA-256.

GNU time records peak RSS in KiB and elapsed seconds separately for signature/delta/patch. The harness also records wall time. First exchange is signature bytes + delta bytes; reused-signature exchange is delta bytes. Full-transfer baseline is target file bytes, not measured network latency. Manifest metadata, authentication and transport overhead are outside this raw-format byte comparison.

The 128 MiB tier explicitly raises CLI budgets to 512 MiB. Each case then confirms that default signature, delta and patch input limits reject these files without creating output, and that patch still rejects output beyond 64 MiB when only its input budget is raised. This proves those Linux sample paths, not general support for multi-gigabyte files or Windows large-file behavior.

The script saves per-case progress after correctness checks and preserves failed-case data on the runner. The benchmark workflow uploads reports, command logs, hardware and tool records, not redundant large generated files. Inputs can be reconstructed with the committed generator and hashes. Archive/package inventory remains unchanged.

Public results will be summarized only after the actual workflow completes. Larger patches, slow paths and unsaved transmission costs are retained. Do not infer a speedup or bandwidth saving merely from the presence of a benchmark script.
