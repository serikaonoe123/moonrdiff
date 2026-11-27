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

## Linux filesystem capacity failure

The Ubuntu job runs `scripts/check_linux_enospc.sh` with the release CLI. It first restores a 2 MiB file with a binding manifest on the runner's normal filesystem and compares every byte. It then restores the same file to a private 1 MiB tmpfs so that the write returns a kernel ENOSPC error.

[Run 44690063732](https://github.com/serikaonoe123/moonrdiff/actions/runs/44690063732) recorded exit status 2, empty stdout and a diagnostic containing the staging path. The final file was absent. The staging file contained 1,044,480 bytes matching the prefix of the expected result. The input SHA-256 hashes and the preexisting file on the small filesystem were unchanged. The script unmounts the temporary filesystem after the checks and publishes the summary and logs as CI artifacts.

This case covers native `patch` reaching the fixed capacity of Linux tmpfs during a write.

### Disk-backed ext4 capacity failure

The same Ubuntu job also uses a fresh 16 MiB file-backed ext4 image. It verifies the mounted loop device belongs to that image and checks the mounted capacity before attempting a bound 24 MiB restore. A byte-for-byte restore on the runner's normal filesystem serves as the control.

[Run 45935855496](https://github.com/serikaonoe123/moonrdiff/actions/runs/45935855496) recorded 11,513,856 bytes of filesystem capacity and a write-stage `ENOSPC`. The CLI returned 2 with empty stdout and reported the staging path. The final path remained absent. All 11,149,312 bytes in the staged file matched the expected prefix. The original input hashes and the preexisting file on ext4 matched their original values. CI also reran the tmpfs and Windows NTFS capacity checks.

## Windows NTFS capacity failure

The Windows job runs `scripts/check_windows_disk_full.ps1` on a GitHub-hosted runner. It creates a new 32 MiB VHD and checks that the attached disk belongs to that image before partitioning and formatting it. The script verifies a bound 48 MiB restore on the runner's normal filesystem, then restores to the small NTFS volume. It dismounts the test image after the checks and uploads the diagnostic, control and summary as CI artifacts.

[Run 44698968496](https://github.com/serikaonoe123/moonrdiff/actions/runs/44698968496) observed a 32,436,224-byte NTFS volume. The bound restore returned exit status 2 with the Windows disk-full diagnostic and empty stdout. The final path remained absent. The 22,171,648-byte staging file matched the expected prefix by SHA-256. The input hashes and the preexisting file on the test volume matched their original values.

This observed failure occurred during the native `patch` write on NTFS. Windows sync failures and crash recovery remain open.

## Linux file sync failure

The Linux verification job runs `scripts/check_linux_sync_failure.sh` against the release CLI. A bound 256 KiB restore serves as the control. The trace confirms that `fsync` succeeds on its staging file, and the published result matches the input byte for byte.

For the failure case, `strace` launches a second restore and injects `EIO` into its `fsync` call. The job checks that the injection occurred exactly once on the staging file's descriptor. [Run 44700198155](https://github.com/serikaonoe123/moonrdiff/actions/runs/44700198155) recorded exit status 2, empty stdout and a diagnostic identifying the retained staging directory and sync error. The final path remained absent, the staging file held all 262,144 expected bytes, and all input hashes matched their original values.

This validates error propagation at the Linux system-call boundary. Physical-device I/O failure and crash recovery remain unverified.

## Windows file sync failure

The Windows verification job runs `scripts/check_windows_output_faults.ps1` on a GitHub-hosted runner. The release CLI serves as the control for a bound 256 KiB restore. The script makes a separate source copy, verifies the pinned async worker's SHA-256, and builds a test-only CLI that can call `FlushFileBuffers` with an invalid handle. The test exercises the original Win32 error-return and propagation path. The original worker and release binary hashes are checked again at the end.

[Run 44855992093](https://github.com/serikaonoe123/moonrdiff/actions/runs/44855992093) recorded the Windows invalid-handle sync diagnostic, exit status 2 and empty stdout. The final path remained absent. The staging file held all 262,144 expected bytes with the same SHA-256, and the inputs retained their hashes. The published control result also matched the expected SHA-256.

This verifies the Windows sync-error path with a deliberately invalid handle. Physical storage failures and recovery after power loss are outside the scope of this test.

## Linux process interruption at publication

The Linux verification job uses `strace` to terminate two separate bound 256 KiB restores. In the first case, the staging file has completed `fsync` and the process is stopped at `renameat2` before the final name appears. In the second case, the rename has succeeded and the process is stopped at `rmdir` before it can remove the empty staging directory.

In [run 45597010772](https://github.com/serikaonoe123/moonrdiff/actions/runs/45597010772), both processes ended with status 137 and empty stdout. The first retained the complete staging file and a new invocation successfully published the expected result while preserving the old staging file. The second retained the full published output and an empty staging directory. A new invocation returned status 2 and refused to overwrite the output. Both cases verified the restored bytes and the original input hashes.

This check covers abrupt loss of the CLI process on the running Linux host. Recovery after filesystem or host power loss remains unverified.

## Windows process interruption at publication

The Windows test-only CLI terminates its own process in two separate bound restores. The first stops after sync and before the rename call. The second stops after rename and before removing the empty staging directory. The unmodified release CLI performs both retries.

[Run 45616502687](https://github.com/serikaonoe123/moonrdiff/actions/runs/45616502687) recorded the test's exit codes 73 and 74 with empty stdout. The pre-rename case retained all 262,144 bytes in staging and the retry restored the final file while preserving the old staging data. The post-rename case retained the complete final file and an empty staging directory. Retrying returned 2 and refused to overwrite the output. Both paths checked the resulting SHA-256 and verified that the inputs and release binary remained unchanged. The Windows sync-error case passed again in the same job.
