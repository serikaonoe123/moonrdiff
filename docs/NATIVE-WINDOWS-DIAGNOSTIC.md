# Local MSVC D8050: read-only diagnostic record

Updated 2026-11-11. The local independent-consumer Native build remains unresolved. Windows/Linux cloud registry consumers pass. No compiler was rerun for this diagnostic, and no ACL, integrity label, security setting, temporary-directory override or compiler flag was changed.

## Observed evidence

- The retained failure is D8050 when the compiler driver cannot place its command line in a debug record. It appears during runtime C-object compilation before consumer tests execute. A sampled failed invocation has about 480 command characters; this alone does not diagnose a path-length issue.
- Installed cl.exe and c1.dll both report file version 19.51.36260.0, under the configured 14.51.36231 toolset directory. File-version agreement does not establish installation health.
- Read-only icacls output shows inherited Low mandatory labels on the workspace and the failed build directory. The current tool process uses an AppContainer-managed TEMP/TMP directory, also Low-labeled. Therefore a simple claim that the current TEMP is Medium and is blocked by no-write-up is not supported by these observations.
- The C: drive had about 1.55 GiB available during inspection. This is resource pressure, not proof of the compiler error's cause. Nothing was deleted or moved.
- Existing source/command logs remain in the failed registry-consumer result directory. Raw account/SID/temp-path details from the inspection are kept out of the public record.

## Interpretation and limits

[Microsoft's MIC documentation](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control) explains that mandatory integrity checks are separate from normal access permissions, and process integrity can be constrained by executable-file labels. This makes execution-context/integrity and temp-resource diagnostics relevant leads. The actual failing process's integrity token, environment and rejected operation were not captured, so no causal chain is confirmed.

[Microsoft's documented D8049](https://learn.microsoft.com/en-us/cpp/error-messages/tool-errors/command-line-error-d8049?view=msvc-170) concerns debug-record path limits. The observed error here is D8050; its similar wording is not sufficient to treat it as D8049 or apply its workaround automatically.

The next useful evidence would be an authorized trace of the failing compiler's process context and file operations. This record does not instruct changing mandatory labels, moving execution outside the sandbox, escalating the compiler or replacing its TEMP/TMP. Until a supported environment fix is established, the existing cloud Native result remains the verified installation result and the local failure remains explicitly recorded.
