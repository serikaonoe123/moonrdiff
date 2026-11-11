# MoonRdiff

MoonBit library for rdiff-compatible signatures, automatic deltas, and patch decoding. Core APIs support JavaScript, Native and Wasm-GC. The native file CLI supports Windows/Linux and optional BLAKE2b-256 file binding manifests.

See the format contract for reviewed root API defaults and lifecycle. Linux synthetic benchmarks cover 1/16/128 MiB; signature/delta performance needs improvement. Tested compiler baseline: 0.10.17+d971670cd. Publication status and registry acceptance for each version are recorded in the GitHub repository.

## Library usage

Import the root package:

```moonbit
import {
  "serikaonoe123/moonrdiff" @rdiff,
}
```

Inside a function that handles errors:

```moonbit
let basis = b"abcdefghijk"
let target = b"prefix-abcdefghijk-suffix"
let sig = @rdiff.parse_signature(@rdiff.signature(basis, block_size=4))
let delta = @rdiff.delta(sig, target, basis_size=basis.length())
let restored = @rdiff.patch(basis, delta, max_output=target.length())
assert_eq(restored, target)
```

Incremental applications use SignatureEncoder, DeltaEncoder and PatchDecoder. Push at most 64 KiB, consume each returned batch, and call finish once at EOF. COPY requests from PatchDecoder require random reads from the old basis. Failed/finished instances cannot resume. Signature block size is capped at 1 MiB in incremental APIs; delta index memory scales with the signature block count.

## Native file CLI

Build from an extracted source package or repository:

```sh
moon update
moon build cmd/moonrdiff --target native
moon run cmd/moonrdiff --target native -- --help
```

Commands: signature, delta, patch, verify and manifest. Existing output paths are refused; input/output limits default to 64 MiB. See [CLI](docs/CLI.md), [format contract](docs/FORMAT.md), and [binding manifests](docs/BINDING.md).

Windows Server 2025 and Ubuntu 24.04 release CLI builds passed five synthetic 128 MiB cases with explicitly raised budgets, plus bound restore/verify of the modified-file case. This is sample acceptance, not general larger-file support or a streaming guarantee for verify.

## Compatibility and limits

Supports the RK/BLAKE2 signature profile and standard rdiff literal/COPY/END delta instructions, with Int32 parameter limits. It does not implement the rsync network protocol or publisher authentication. Binding manifests require a trusted source. Input stability and partial-output handling are described in the CLI contract; no transactional or snapshot guarantee is made.

## License

Original MoonRdiff code is MIT. The adapted BLAKE2 package retains Apache-2.0, its full [license](third_party/mooncry_blake2/LICENSE) and [source/modification notice](third_party/mooncry_blake2/NOTICE.md). Native CLI dependency moonbitlang/async@0.19.3 is Apache-2.0. librsync is an external interoperability oracle and is not bundled.

Source and development verification: [GitHub](https://github.com/serikaonoe123/moonrdiff).
