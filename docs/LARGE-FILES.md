# Cross-platform 128 MiB acceptance

This gate checks generated files with the pinned MoonBit compiler on Windows and Linux. It is distinct from Linux GNU-time/rdiff performance comparisons. Only a successful default invocation can establish the five-case 128 MiB acceptance described here.

```sh
moon update
moon build cmd/moonrdiff --target native --release --deny-warn
python scripts/check_large_files.py
```

The script invokes the existing benchmark generator in generation-only mode for identical, 4096-byte modified, insert/delete, unrelated random and gzip fixtures. Nominal raw size is 128 MiB; compressed file size can differ. Inputs, outputs and command logs are created only under fresh results directories. It records compiler/platform/source/binary identities and retains its fixture report/hash.

For each case it generates a 4096-byte-block signature, calculates a delta using only signature/target/basis-size arguments, restores the result, and compares independent streaming SHA-256 hashes. Budgets are explicitly raised to 512 MiB for these paths; this does not establish acceptance of actual 512 MiB inputs or multi-gigabyte files.

Each case also checks four expected failures without creating a result: default signature input limit, default delta target limit, default patch input limit, and default patch output limit after raising only its input allowance. Every failure must be exit 2, empty stdout and the exact expected budget reason. This gives 20 budget controls per platform, separate from successful file operations.

For the modified case it additionally runs CLI verify, creates a binding manifest, checks all three BLAKE2b-256 identities using Python hashlib, and restores with that manifest. Independent SHA-256 verifies the bound result, and the CLI must report manifest_verified=true. Default verify and manifest input limits must also refuse the 128 MiB files (two extra controls). The originally archived CLI verify read both files into memory; that historical result does not establish bounded reads. Current development sources use 64 KiB comparison reads, with current-run acceptance recorded separately in VALIDATION.md.

The optional `--size-mib 1` mode is a harness smoke check with full_128mib_acceptance=false. It does not run the 128 MiB default-limit controls and cannot substitute for the gate. Initial local smoke results are recorded in VALIDATION.md.

The dedicated workflow runs on both platforms for source changes, pull requests and manual dispatch. It uploads compact acceptance reports, generator reports and command logs. Large generated files are not distributed in artifacts; their hashes and generation settings support regeneration. Gzip byte equality across differing zlib environments is not assumed. This gate does not promise snapshots, transactional output publication or publisher authentication.

## Verified result: 2026-11-11

Commit `d072e747af3caedf5aee610643052e88aa610245` passed [large-file run 42950792459](https://github.com/serikaonoe123/moonrdiff/actions/runs/42950792459) on Windows Server 2025 and Ubuntu 24.04, using the pinned compiler in release mode. [Regular CI 42950792531](https://github.com/serikaonoe123/moonrdiff/actions/runs/42950792531) also passed. Each platform completed all five nominal 128 MiB cases, 20 core budget rejection controls, the bound modified-file restore with independent manifest hashes, CLI verify, and two additional default verify/manifest budget refusals. Both full_128mib_acceptance flags are true.

Downloaded reports match all five official LARGE_FILE_RESULT log entries per platform and their generator-report SHA-256 values. Four uncompressed cases have identical input, signature and delta hashes across platforms; gzip input hashes also happened to match in this run, without establishing that for other zlib environments.

Original acceptance and generator reports are preserved without modification:

- [Windows acceptance](../benchmarks/large-files-2026-11-11/windows.json), SHA-256 `3b996c565f68257424ab912d48fdfda17d0beb5d3e35812c4b6e978190e97658`.
- [Linux acceptance](../benchmarks/large-files-2026-11-11/linux.json), SHA-256 `d6921765cad78265cef29e75e01bed1e8f72a7e5c3280be52b3046513add5289`.
- [Windows fixtures](../benchmarks/large-files-2026-11-11/fixtures-windows.json) and [Linux fixtures](../benchmarks/large-files-2026-11-11/fixtures-linux.json).

The snapshot directory has a Git -text attribute so Windows CRLF bytes survive commits/checkouts. Regular Windows/Linux CI audits all four original SHA-256 values with scripts/check_evidence.py; parsing equivalent JSON is not a substitute for that byte check.

This closes the planned Windows 128 MiB sample gap for these release CLI paths. It does not establish debug-build 128 MiB acceptance, every Windows/Linux environment, larger files or bound restoration of every fixture type. Bind/verify large-file paths were checked on the modified fixture; unbound restore covered all five types.
