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
$normalCall = 'FlushFileBuffers(fsync_job->fd)'
$testCall = 'FlushFileBuffers(NULL)'
$workerText = [IO.File]::ReadAllText($worker)
if ((Get-Sha256 $worker) -ne $approvedHash -or
    [regex]::Matches($workerText, [regex]::Escape($normalCall)).Count -ne 1) {
    throw 'The copied worker does not have the expected Windows sync call.'
}
# Keep the real Win32 error return and propagation in the test build.
[IO.File]::WriteAllText($worker, $workerText.Replace($normalCall, $testCall))
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
& $testCli patch $basis $delta $destination --manifest $manifest > $stdout 2> $stderr
$status = $LASTEXITCODE
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
foreach ($inputPath in $inputHashes.Keys) {
    if ((Get-Sha256 $inputPath) -ne $inputHashes[$inputPath]) { throw "Input changed: $inputPath" }
}
if ((Get-Sha256 $dependency) -ne $approvedHash -or (Get-Sha256 $normalCli) -ne $normalCliHash) {
    throw 'The original worker or release binary changed.'
}

[ordered]@{
    result            = 'passed'
    commit            = (git rev-parse HEAD).Trim()
    sync_call         = $testCall
    error             = 'ERROR_INVALID_HANDLE'
    exit_status       = $status
    staged_bytes      = [IO.FileInfo]::new($staged).Length
    worker_sha256     = $approvedHash
    test_worker_sha256 = $testWorkerHash
} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $report 'summary.json')
