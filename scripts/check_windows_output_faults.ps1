param(
    [Parameter(Mandatory)]
    [string]$Cli
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (!$IsWindows -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'This check requires a disposable GitHub-hosted Windows runner.'
}

function Invoke-SetupCommand([string]$Program, [string[]]$Arguments, [string]$Log) {
    & $Program @Arguments > $Log
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with $LASTEXITCODE. See $Log."
    }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Invoke-TestPatch([string]$Mode, [string]$Destination, [string]$Log) {
    $oldMode = $env:MOONRDIFF_TEST_OUTPUT_FAULT
    try {
        $env:MOONRDIFF_TEST_OUTPUT_FAULT = $Mode
        & $testCli patch $basis $delta $Destination --manifest $manifest > "$Log.stdout" 2> "$Log.stderr"
        $LASTEXITCODE
    }
    finally {
        $env:MOONRDIFF_TEST_OUTPUT_FAULT = $oldMode
    }
}

$normalCli = (Resolve-Path -LiteralPath $Cli).ProviderPath
$normalCliHash = Get-Sha256 $normalCli
$id = [guid]::NewGuid().ToString('N')
New-Item -ItemType Directory -Path results -Force | Out-Null
$report = (New-Item -ItemType Directory -Path "results/windows-sync-failure-$id").FullName
$source = (New-Item -ItemType Directory -Path (Join-Path $env:RUNNER_TEMP "rdiff-sync-$id")).FullName
$archive = Join-Path $report 'source.tar'
$dependency = '.mooncakes/moonbitlang/async/src/internal/event_loop/thread_pool.c'
$approvedHash = '2ADBE825D6E7F23F0FFBB2E9D9514B9E597FEF91BA52DC8628CEE0BA180B3F3D'

if ((Get-Sha256 $dependency) -ne $approvedHash) { throw 'Unexpected async 0.19.3 worker bytes.' }
Write-Host "Windows sync-failure evidence: $report"
Invoke-SetupCommand 'git' @('archive', '--format=tar', '-o', $archive, 'HEAD') (Join-Path $report 'setup.log')
Invoke-SetupCommand 'tar.exe' @('-xf', $archive, '-C', $source) (Join-Path $report 'extract.log')
Copy-Item -LiteralPath '.mooncakes' -Destination (Join-Path $source '.mooncakes') -Recurse

$worker = Join-Path $source $dependency
$workerText = [IO.File]::ReadAllText($worker)
if ((Get-Sha256 $worker) -ne $approvedHash) { throw 'The worker copy has unexpected bytes.' }

# This code is compiled only in the isolated test copy.
$faultSelector = @'
#ifdef _WIN32
static int moonrdiff_test_output_fault(WCHAR expected) {
  WCHAR mode[2];
  return GetEnvironmentVariableW(L"MOONRDIFF_TEST_OUTPUT_FAULT", mode, 2) == 1
    && mode[0] == expected;
}
#endif
'@
$lf = [char]10
$syncWorker = "static${lf}void fsync_job_worker"
$windowsRename = '  BOOL ret = SetFileInformationByHandle(handle, FileRenameInfoEx, info, buffer_size);'
$windowsCleanup = '  if (!RemoveDirectoryW((LPCWSTR)rmdir_job->path))'
$edits = [ordered]@{
    $syncWorker = $faultSelector + $lf + $lf + $syncWorker
    'FlushFileBuffers(fsync_job->fd)' = "FlushFileBuffers(moonrdiff_test_output_fault(L's') ? NULL : fsync_job->fd)"
    $windowsRename = "  if (moonrdiff_test_output_fault(L'b')) TerminateProcess(GetCurrentProcess(), 73);" + $lf + $windowsRename
    $windowsCleanup = "  if (moonrdiff_test_output_fault(L'a')) TerminateProcess(GetCurrentProcess(), 74);" + $lf + $windowsCleanup
}
foreach ($original in $edits.Keys) {
    if ([regex]::Matches($workerText, [regex]::Escape($original)).Count -ne 1) {
        throw "Expected exactly one Windows test-build substitution: $original"
    }
    $workerText = $workerText.Replace($original, $edits[$original])
}
[IO.File]::WriteAllText($worker, $workerText)
$testWorkerHash = Get-Sha256 $worker
Push-Location -LiteralPath $source
try {
    $buildLog = Join-Path $report 'build.log'
    moon build cmd/moonrdiff --target native --release --deny-warn --frozen > $buildLog 2>&1
    if ($LASTEXITCODE -ne 0) {
        Get-Content -Tail 40 -LiteralPath $buildLog
        throw "The test-only build failed. See $buildLog."
    }
    $testCli = (Resolve-Path -LiteralPath '_build/native/release/build/cmd/moonrdiff/moonrdiff.exe').ProviderPath
}
finally {
    Pop-Location
}
if ((Get-Sha256 $worker) -ne $testWorkerHash -or (Get-Sha256 $testCli) -eq $normalCliHash) {
    throw 'The test-only build did not preserve the modified worker or produce a separate binary.'
}

$basis = Join-Path $report 'basis.bin'
$signature = Join-Path $report 'basis.sig'
$delta = Join-Path $report 'update.delta'
$manifest = Join-Path $report 'binding.json'
$control = Join-Path $report 'control.bin'
$destination = Join-Path $report 'restored.bin'
$targetBytes = 256KB
$bytes = [byte[]]::new($targetBytes)
[Array]::Fill[byte]($bytes, 0xA5)
[IO.File]::WriteAllBytes($basis, $bytes)
Invoke-SetupCommand $normalCli @('signature', $basis, $signature) (Join-Path $report 'signature.json')
Invoke-SetupCommand $normalCli @('delta', $signature, $basis, $delta, '--basis-size', "$targetBytes") (Join-Path $report 'delta.json')
Invoke-SetupCommand $normalCli @('manifest', $basis, $basis, $delta, $manifest) (Join-Path $report 'manifest.json')
$inputHashes = @{}
foreach ($inputPath in $basis, $delta, $manifest) { $inputHashes[$inputPath] = Get-Sha256 $inputPath }

$controlLog = Join-Path $report 'control.json'
Invoke-SetupCommand $normalCli @('patch', $basis, $delta, $control, '--manifest', $manifest) $controlLog
$controlReport = Get-Content -Raw -LiteralPath $controlLog | ConvertFrom-Json
if (!$controlReport.manifest_verified -or (Get-Sha256 $control) -ne $inputHashes[$basis]) {
    throw 'The unmodified release control did not restore the expected file.'
}

$stdout = Join-Path $report 'sync-failure.stdout'
$stderr = Join-Path $report 'sync-failure.stderr'
$status = Invoke-TestPatch 's' $destination (Join-Path $report 'sync-failure')
$diagnostic = [IO.File]::ReadAllText($stderr)
Write-Host $diagnostic
if ($status -ne 2 -or [IO.FileInfo]::new($stdout).Length -ne 0 -or (Test-Path -LiteralPath $destination)) {
    throw 'Expected exit 2, empty stdout, and no published file.'
}
if (!$diagnostic.Contains('@fs.File::sync(): The handle is invalid.')) {
    throw 'The expected Windows sync error was not reported.'
}
$stages = [IO.Directory]::GetDirectories($report, 'restored.bin.moonrdiff-stage-*')
if ($stages.Length -ne 1 -or ($diagnostic -split '\r?\n') -cnotcontains
    "moonrdiff: Output was not published. Staging evidence: $($stages[0])") {
    throw 'The diagnostic did not identify the retained staging directory.'
}
$staged = [IO.Path]::Combine($stages[0], 'data')
if ((Get-Sha256 $staged) -ne $inputHashes[$basis]) { throw 'The staged file differs from the expected full output.' }

$before = Join-Path $report 'before.bin'
$beforeLog = Join-Path $report 'before-interruption'
$beforeStatus = Invoke-TestPatch 'b' $before $beforeLog
$beforeStages = [IO.Directory]::GetDirectories($report, 'before.bin.moonrdiff-stage-*')
if ($beforeStatus -ne 73 -or [IO.FileInfo]::new("$beforeLog.stdout").Length -ne 0 -or
    (Test-Path -LiteralPath $before) -or $beforeStages.Length -ne 1) {
    throw 'Expected interruption after sync and before publication.'
}
$beforeStaged = [IO.Path]::Combine($beforeStages[0], 'data')
if ((Get-Sha256 $beforeStaged) -ne $inputHashes[$basis]) { throw 'The interrupted staging file is incomplete.' }
$beforeRetry = Join-Path $report 'before-retry.json'
Invoke-SetupCommand $normalCli @('patch', $basis, $delta, $before, '--manifest', $manifest) $beforeRetry
if (!(Get-Content -Raw -LiteralPath $beforeRetry | ConvertFrom-Json).manifest_verified -or
    (Get-Sha256 $before) -ne $inputHashes[$basis] -or (Get-Sha256 $beforeStaged) -ne $inputHashes[$basis]) {
    throw 'Retry before publication did not restore the output and preserve the older staging file.'
}

$after = Join-Path $report 'after.bin'
$afterLog = Join-Path $report 'after-interruption'
$afterStatus = Invoke-TestPatch 'a' $after $afterLog
$afterStages = [IO.Directory]::GetDirectories($report, 'after.bin.moonrdiff-stage-*')
if ($afterStatus -ne 74 -or [IO.FileInfo]::new("$afterLog.stdout").Length -ne 0 -or
    $afterStages.Length -ne 1 -or [IO.Directory]::GetFileSystemEntries($afterStages[0]).Length -ne 0 -or
    (Get-Sha256 $after) -ne $inputHashes[$basis]) {
    throw 'Expected interruption after publication and before removal of the empty stage.'
}
$retryLog = Join-Path $report 'after-retry'
& $normalCli patch $basis $delta $after --manifest $manifest > "$retryLog.stdout" 2> "$retryLog.stderr"
$afterRetryStatus = $LASTEXITCODE
if ($afterRetryStatus -ne 2 -or [IO.FileInfo]::new("$retryLog.stdout").Length -ne 0 -or
    ![IO.File]::ReadAllText("$retryLog.stderr").Contains('Output already exists') -or
    (Get-Sha256 $after) -ne $inputHashes[$basis]) {
    throw 'Retry after publication did not refuse to overwrite the existing output.'
}

foreach ($inputPath in $inputHashes.Keys) {
    if ((Get-Sha256 $inputPath) -ne $inputHashes[$inputPath]) { throw "Input changed: $inputPath" }
}
if ((Get-Sha256 $dependency) -ne $approvedHash -or (Get-Sha256 $normalCli) -ne $normalCliHash) {
    throw 'The original worker or release binary changed.'
}

[ordered]@{
    result            = 'passed'
    commit            = (git rev-parse HEAD).Trim()
    sync_call         = 'FlushFileBuffers(NULL)'
    error             = 'ERROR_INVALID_HANDLE'
    exit_status       = $status
    staged_bytes      = [IO.FileInfo]::new($staged).Length
    worker_sha256     = $approvedHash
    test_worker_sha256 = $testWorkerHash
    before_exit_status = $beforeStatus
    before_retry       = 'restored'
    after_exit_status  = $afterStatus
    after_retry        = 'refused'
} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $report 'summary.json')
