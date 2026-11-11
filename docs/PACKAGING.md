# Packaging and independent-consumer acceptance

Published version: serikaonoe123/moonrdiff@0.1.0. This script remains the archive gate; separate completed registry acceptance is recorded in RELEASE-0.1.0.md.

Main currently prepares the unpublished 0.1.1 documentation candidate. check_package.py derives the archive version from moon.mod; check_registry.py binds its standalone consumer dependency to the selected approved inventory's version, so the 0.1.0 registry workflow continues to test the already published package.

Run with the pinned compiler:

```sh
moon update
python scripts/check_package.py
```

The script runs moon package --frozen, then inspects the actual ZIP against the exhaustive committed packaging/files.txt allowlist. There are 34 files: core library/tests, native CLI source, three user documents, the consumer README, original MIT license, and attributed Apache-2.0 BLAKE2 code/license/notice. Development scripts, internal probe, examples, execution results and local publishing helpers are excluded by .moonignore. Every archive file is compared byte-for-byte with its source; file and archive SHA-256 values are recorded.

The script creates a new workspace containing only the extracted archive and a copy of examples/consumer. Dependency resolution is inspected: MoonRdiff must resolve to that extraction, never the original checkout; async must resolve to registry 0.19.3. Five public-API consumer tests execute on JS, Native and Wasm-GC. The archive's native CLI is built and runs signature → delta → manifest → bound patch → verify on generated files.

The module metadata declares MIT AND Apache-2.0. The original root license and the full third-party license/notice remain in the archive; the official async dependency is not vendored. README relative links are checked against package contents.

Local-only diagnostic options `--targets js wasm-gc --skip-native-cli` explicitly produce a partial report. Default Windows/Linux CI passes neither option. Local MSVC D8050 in the new workspace was retained as a failure, not treated as a package pass; cloud native results must be verified separately.

Each test preserves its report, resolution record and complete command output under results/package-*. Outputs are ignored by Git. Archive SHA-256 describes that concrete build, not cross-platform ZIP reproducibility: ZIP metadata and source line endings can affect archive bytes.

Successful package checks also retain that actual ZIP beside the report, which records the source commit and module version read from moon.mod. This supports review of a concrete candidate archive and its 34-file content inventory.

After authorized publication, use `python scripts/check_registry.py --approved-inventory PATH_TO_SUCCESSFUL_PACKAGE_REPORT`. It creates a fresh standalone consumer, requires registry resolution of exactly 0.1.0, compares all approved source-file hashes in the downloaded module and runs the five public tests on all three backends. It contains no publishing or credential-changing commands. It passed Windows/Linux registry acceptance after the 0.1.0 upload; source-only resolution and byte comparisons are recorded separately from this archive gate.

Before public publication: select a concrete tested commit/version; recheck package inventory and metadata; finish representative benchmark/large-file acceptance; review API status and release notes; then obtain the applicable publication authorization. After publication, run a new consumer that resolves from Mooncakes, without a local MoonRdiff workspace member. The current consumer deliberately cannot prove registry availability.

Publishing policy follows the official [.moonignore documentation](https://docs.moonbitlang.com/en/stable/toolchain/moon/module.html#publishing-files-with-moonignore) and is verified using the actual pinned toolchain rather than assumed from documentation alone.
