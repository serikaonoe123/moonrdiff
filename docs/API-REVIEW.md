# API review for the 0.1.0 candidate

Scope: the public root package in pkg.generated.mbti, its three backend builds and the native CLI contracts. Module 0.1.0 is an unpublished pre-1.0 candidate; this review is not a promise of 1.x compatibility or a registry-installation result. The third_party/mooncry_blake2 package remains an attributed implementation dependency, not the supported application integration surface.

The existing root signatures were retained. No new error variants, renamed parameters or budget defaults were introduced. FORMAT.md now lists actual defaults, required budgets and mutable-object lifecycle. The review corrected stale claims that all APIs were in memory and that no binding manifest existed.

| Area | Reviewed decision / evidence |
| --- | --- |
| Ownership | Signature is opaque; incremental objects keep mutable state and aliases share it. Failed/finished objects cannot resume. |
| Empty input / counters | Empty signature is a valid 12-byte header; empty delta includes header and END. Signature counters count emitted header/records and pending bytes separately. |
| Errors | Public DeltaError::Invalid(String) can be caught by a consumer. Message wording is not a stable machine-readable API. |
| Provisional output | Drain batches but do not publish them as verified before finish. Truncation or a later budget failure invalidates prior batches. |
| Resource limits | 64 KiB pushes and 1 MiB incremental block cap; cumulative target/output/comparison budgets; index scales with block count plus a capped 64 KiB hint table. |
| In-memory helpers | encode has no byte-budget argument, and patch has no instruction-count argument. Caller controls allocations; budgeted incremental alternatives are documented. No uniform CLI/library budget promise is made. |
| Format compatibility | Supported profile/opcode set remains fixed; parameter limits remain Int32. Signature count does not authenticate basis size; patch encoding need not be canonical across versions. |
| File adapter | Exclusive new outputs and two-pass preflight remain; same-size mutations, partial new files and lack of transactional publication are documented. |
| Binding | Separate native manifest uses standard BLAKE2b-256 and requires a trusted source. Publisher authentication and distributed manifest creation are outside this candidate. |

The independent consumer now has five public-only test groups: the README in-memory example, incremental update with COPY callbacks, default/empty/counter behavior, typed errors and terminal states, and cumulative budgets across pushes. It imports no private package, consumes the extracted actual archive and must pass on JS/Native/Wasm-GC. The package gate also checks the complete 34-file inventory and an extracted native CLI update/manifest flow.

Local isolated JS/Wasm-GC checks and full cloud outcomes are recorded in VALIDATION.md. The known local isolated-native MSVC failure is not retried through alternate permissions/toolchains. Publication requires a concrete tested commit and package content inventory, then explicit applicable authorization; registry-consumer acceptance follows upload and remains pending until then.

Candidate commit e09db0b passed full Windows/Linux CI 42955589065. Both platforms ran five consumer groups on each backend and passed the extracted native CLI flow. The actual archives were downloaded and every file was checked against that commit; the 34 content records match across platforms. The concrete version/commit/content proposal is in RELEASE-PROPOSAL-0.1.0.md. Registry resolution remains a post-publication gate.
