# Local MSVC D8050: diagnostic and recovery record

Updated 2026-11-19. D8050 can affect both Git Bash and PowerShell when launching a full MoonBit build in the same diagnostic execution context. A fresh build from the normal local PowerShell context succeeded. The root cause remains unconfirmed.

## Observed evidence

- The retained original failure is D8050 when the compiler driver cannot place its command line in a debug record. It appeared during runtime C-object compilation before consumer tests executed. A sampled failed invocation has about 480 command characters; this alone does not diagnose a path-length issue.
- Installed cl.exe and c1.dll both report file version 19.51.36260.0, under the configured 14.51.36231 toolset directory. File-version agreement does not establish installation health.
- Read-only icacls output shows inherited Low mandatory labels on the workspace and the failed build directory. The current tool process uses an AppContainer-managed TEMP/TMP directory, also Low-labeled. Therefore a simple claim that the current TEMP is Medium and is blocked by no-write-up is not supported by these observations.
- The C: drive had about 1.55 GiB available during the initial read-only inspection. A later separately authorized C/C++ cache cleanup reclaimed about 3.90 GiB, and about 5.32 GiB was available just before revalidation. These observations do not prove that disk pressure caused D8050. No compiler, workspace or temporary-directory permissions were modified during that cleanup.
- Existing source/command logs remain in the failed registry-consumer result directory. Raw account/SID/temp-path details from the inspection are kept out of the public record.

## Interpretation and limits

[Microsoft's MIC documentation](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control) explains that mandatory integrity checks are separate from normal access permissions, and process integrity can be constrained by executable-file labels. This makes execution-context/integrity and temp-resource diagnostics relevant leads. The actual failing process's integrity token, environment and rejected operation were not captured, so no causal chain is confirmed.

[Microsoft's documented D8049](https://learn.microsoft.com/en-us/cpp/error-messages/tool-errors/command-line-error-d8049?view=msvc-170) concerns debug-record path limits. The observed error here is D8050; its similar wording is not sufficient to treat it as D8049 or apply its workaround automatically.

The failing process's context and rejected operation were not captured when the error occurred. No controlled single-variable experiment establishes why the later builds succeed: disk availability and per-tool execution context are not proven causes. If the error returns, a trace of that failing process would be useful. This record does not instruct changing mandatory labels, moving execution outside the sandbox, escalating the compiler or replacing its TEMP/TMP. Preserve the original failure separately from subsequent successful runs.

## Local recovery revalidation

The user requested continued diagnosis. With the same fixed MoonBit 0.10.17+d971670cd and installed MSVC file version 19.51.36260.0:

- Reran the original `moon test --package moonrdiff-example/consumer --target native --deny-warn` in the retained failed registry 0.1.0 consumer directory. The command exited 0, runtime C compilation was observed, and all five public consumer groups passed. The original commands.log and failed report were retained; the new output is separate at results/native-d8050-20261111/original-consumer-rerun.log and its JSON report.
- Checked, tested and built the current root package for Native with warnings denied. All 27 tests passed on source commit 0ea95407cd32d327e62e3700187fac27f4b53533.
- Ran the complete default scripts/check_package.py without partial/skip flags. It created a fresh workspace from the actual 34-file archive; five public consumer groups passed on each of JS/Native/Wasm-GC, and the packaged native signature/delta/manifest/patch/verify flow passed. The fresh Native consumer log includes runtime C compilation, so this result does not depend solely on the old failed directory's build outputs.

The fresh archive report is results/package-d561c1ecff234317a06d66a544b7fa0d/report.json, SHA-256 `1b76bd7a306cac744d3e89cad6468edab3a4f9b662fde9c3e3a97066226800fd`. The combined local record is results/native-d8050-20261111/recovery-summary.json. These are local working-source/archive results, not a new registry-only 0.1.1 installation or a new publication. Existing Windows/Linux registry evidence remains separately recorded.

The November 11 revalidation recovered the local Native paths. It used the same compiler, access settings, compiler flags and temporary-directory configuration.

Official OpenAI documentation's [Windows sandbox guidance](https://learn.chatgpt.com/docs/windows/windows-sandbox) describes inspecting effective permissions/configuration and retaining managed sandbox boundaries. It does not document D8050 or establish a fix for this machine. No sandbox-mode or product-configuration changes were made based on that guidance.

## November 19 walkthrough

The new checkout at `d911258` reported D8050 while compiling runtime C objects from Git Bash with the pinned toolchain. The same `moon build cmd/moonrdiff --target native --release --deny-warn` in PowerShell compiled the runtime and CLI in that checkout. The resulting executable passed a bound restore, byte comparison and the mismatch exit-code check. This observed difference does not isolate the cause. The walkthrough uses PowerShell for the Windows Native build. Local logs are under `results/guide-0.1.3/`. [Acceptance guide](ACCEPTANCE.md)

## November 19 controlled follow-up

The standalone test invoked the same `cl.exe` with identical arguments and a one-line C fixture. All four runs used `/Z7`. The MoonBit comparison built the same checkout `d911258` with `0.10.17+d971670cd` and fresh, equal-length output directory names on the workspace drive. The Git Bash launcher and native launch from PowerShell ran within the same diagnostic invocation. The normal PowerShell run used a separate invocation. [Microsoft reference for `/Z7`](https://learn.microsoft.com/en-us/cpp/build/reference/z7-zi-zi-debug-information-format?view=msvc-170)

| Local test | Observed result |
| --- | --- |
| Standalone C compilation from both shells | Two passes per shell, with four object files produced |
| Full MoonBit Native build from both shells in the diagnostic invocation | D8050 during runtime C object compilation in both cases |
| Full build with default parallelism and with `--jobs 1` in a follow-up diagnostic invocation | D8050 in both cases |
| Full build in normal local PowerShell | Runtime and CLI compiled in a fresh output directory. The resulting CLI returned `matched: true` when comparing the 13-byte guide fixture and its restored copy. |

The successful full build started with 243,748,864 free bytes on C:, below both failures in the first full-build comparison. Available space on C: alone does not explain that difference. The sampled parent processes in the two execution contexts reported different normalized `TEMP` and `TMP` paths. That observation does not identify the failing file operation or establish the temporary directory as the cause. On recurrence, capture the failing compiler child's environment and first failed operation before comparing with a successful run. Local logs and the comparison report are under `results/d8050-followup-20261119/`.
