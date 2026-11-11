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

For the modified case it additionally runs CLI verify, creates a binding manifest, checks all three BLAKE2b-256 identities using Python hashlib, and restores with that manifest. Independent SHA-256 verifies the bound result, and the CLI must report manifest_verified=true. Default verify and manifest input limits must also refuse the 128 MiB files (two extra controls). CLI verify still reads both files into memory; passing this test does not make verify a streaming API.

The optional `--size-mib 1` mode is a harness smoke check with full_128mib_acceptance=false. It does not run the 128 MiB default-limit controls and cannot substitute for the gate. Initial local smoke results are recorded in VALIDATION.md; actual cloud outcomes must be inspected before claiming Windows acceptance.

The dedicated workflow runs on both platforms for source changes, pull requests and manual dispatch. It uploads compact acceptance reports, generator reports and command logs. Large generated files are not distributed in artifacts; their hashes and generation settings support regeneration. Gzip byte equality across differing zlib environments is not assumed. This gate does not promise snapshots, transactional output publication or publisher authentication.
