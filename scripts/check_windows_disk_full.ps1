param(
    [Parameter(Mandatory)]
    [string]$Cli
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (!$IsWindows -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'This check requires a disposable GitHub-hosted Windows runner.'
}

function New-ZeroFile([string]$Path, [long]$Length) {
    $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew)
    try { $file.SetLength($Length) } finally { $file.Dispose() }
}

function Get-Sha256([string]$Path) {
    $file = [IO.File]::OpenRead($Path)
    try { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($file)) }
    finally { $file.Dispose() }
}

function Invoke-Control([string]$Log, [string[]]$Arguments) {
    & $executable @Arguments > $Log
    if ($LASTEXITCODE -ne 0) { throw "Control command failed: $($Arguments[0]) ($LASTEXITCODE)" }
}

$executable = (Resolve-Path -LiteralPath $Cli).ProviderPath
$id = [guid]::NewGuid().ToString('N')
New-Item -ItemType Directory -Path results -Force | Out-Null
$reportDir = (New-Item -ItemType Directory -Path "results/windows-disk-full-$id").FullName
$imageDir = (New-Item -ItemType Directory -Path (Join-Path $env:RUNNER_TEMP "moonrdiff-disk-full-$id")).FullName
$imagePath = Join-Path $imageDir 'capacity.vhd'
$diskpartScript = Join-Path $imageDir 'create.txt'
$capacityMiB = 32
$targetBytes = 48MB
$basis = Join-Path $reportDir 'basis.bin'
$signature = Join-Path $reportDir 'basis.sig'
$delta = Join-Path $reportDir 'update.delta'
$manifest = Join-Path $reportDir 'binding.json'
$control = Join-Path $reportDir 'control.bin'
$controlLog = Join-Path $reportDir 'control.json'
$stdout = Join-Path $reportDir 'disk-full.stdout'
$stderr = Join-Path $reportDir 'disk-full.stderr'

Write-Host "Windows disk-full evidence: $reportDir"
New-ZeroFile $basis $targetBytes
Invoke-Control (Join-Path $reportDir 'signature.json') @('signature', $basis, $signature)
Invoke-Control (Join-Path $reportDir 'delta.json') @('delta', $signature, $basis, $delta, '--basis-size', "$targetBytes")
Invoke-Control (Join-Path $reportDir 'manifest.json') @('manifest', $basis, $basis, $delta, $manifest)
$inputHashes = @{}
foreach ($inputPath in $basis, $delta, $manifest) { $inputHashes[$inputPath] = Get-Sha256 $inputPath }

Invoke-Control $controlLog @('patch', $basis, $delta, $control, '--manifest', $manifest)
$controlReport = Get-Content -Raw -LiteralPath $controlLog | ConvertFrom-Json
if (!$controlReport.manifest_verified -or (Get-Sha256 $control) -ne $inputHashes[$basis]) {
    throw 'The bound restore on the normal filesystem did not match.'
}

# DiskPart only creates a new image file. All storage mutations use objects
# resolved from that one image after confirming it is fresh and capacity-limited.
if ([IO.File]::Exists($imagePath)) { throw 'The test disk image already exists.' }
Set-Content -LiteralPath $diskpartScript -Encoding ASCII -Value "create vdisk file=`"$imagePath`" maximum=$capacityMiB type=expandable"
& (Join-Path $env:SystemRoot 'System32/diskpart.exe') /s $diskpartScript > (Join-Path $reportDir 'diskpart.log')
if ($LASTEXITCODE -ne 0 -or ![IO.File]::Exists($imagePath)) { throw 'Could not create the test VHD.' }

$mounted = $false
try {
    Mount-DiskImage -ImagePath $imagePath -StorageType VHD -NoDriveLetter
    $mounted = $true
    $disks = @(Get-DiskImage -ImagePath $imagePath | Get-Disk)
    if ($disks.Count -ne 1) { throw 'Expected exactly one disk associated with the test VHD.' }
    $disk = $disks[0]
    if ($disk.IsBoot -or $disk.IsSystem -or $disk.PartitionStyle -ne 'RAW' -or
        $disk.Size -lt 30MB -or $disk.Size -gt ($capacityMiB * 1MB)) {
        throw 'The disk associated with the test VHD was not a fresh 32 MiB disk.'
    }
    $initialized = Initialize-Disk -InputObject $disk -PartitionStyle MBR -PassThru
    $partition = $initialized | New-Partition -UseMaximumSize -AssignDriveLetter
    if ($partition.DiskNumber -ne $disk.Number -or !$partition.DriveLetter) {
        throw 'The assigned partition does not identify the test disk.'
    }
    $volume = $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel MoonRdiffTest -Confirm:$false
    if ($volume.FileSystem -ne 'NTFS' -or $volume.Size -gt $disk.Size -or
        $volume.SizeRemaining -lt 1MB -or $volume.DriveLetter -ne $partition.DriveLetter) {
        throw 'Could not confirm the small NTFS volume and its assigned drive letter.'
    }

    $root = '{0}:\' -f $partition.DriveLetter
    $destination = [IO.Path]::Combine($root, 'restored.bin')
    $sentinel = [IO.Path]::Combine($root, 'existing.txt')
    [IO.File]::WriteAllText($sentinel, 'existing data')
    $sentinelHash = Get-Sha256 $sentinel

    & $executable patch $basis $delta $destination --manifest $manifest > $stdout 2> $stderr
    $status = $LASTEXITCODE
    $diagnostic = [IO.File]::ReadAllText($stderr)
    Write-Host $diagnostic
    if ($status -ne 2 -or [IO.FileInfo]::new($stdout).Length -ne 0 -or [IO.File]::Exists($destination)) {
        throw 'Expected exit 2, empty stdout, and no final file.'
    }
    if ($diagnostic -notmatch 'not enough space on the disk|disk is full|ERROR_DISK_FULL') {
        throw 'The OS did not report a disk-full write.'
    }
    $stages = [IO.Directory]::GetDirectories($root, 'restored.bin.moonrdiff-stage-*')
    if ($stages.Length -ne 1 -or ($diagnostic -split '\r?\n') -cnotcontains
        "moonrdiff: Output was not published. Staging evidence: $($stages[0])") {
        throw 'The diagnostic did not identify the retained staging directory.'
    }
    $partial = [IO.Path]::Combine($stages[0], 'data')
    $partialBytes = [IO.FileInfo]::new($partial).Length
    if ($partialBytes -le 0 -or $partialBytes -ge $targetBytes) { throw 'Expected a partial staging file.' }
    $expectedPrefix = Join-Path $reportDir 'expected-prefix.bin'
    New-ZeroFile $expectedPrefix $partialBytes
    if ((Get-Sha256 $partial) -ne (Get-Sha256 $expectedPrefix)) { throw 'Wrong staging file content.' }
    if ((Get-Sha256 $sentinel) -ne $sentinelHash) { throw 'The preexisting file changed.' }
    foreach ($inputPath in $inputHashes.Keys) {
        if ((Get-Sha256 $inputPath) -ne $inputHashes[$inputPath]) { throw "Input changed: $inputPath" }
    }
}
finally {
    if ($mounted) { Dismount-DiskImage -ImagePath $imagePath }
}

[ordered]@{
    result          = 'passed'
    commit          = (git rev-parse HEAD).Trim()
    filesystem      = 'NTFS'
    disk_bytes      = $disk.Size
    volume_bytes    = $volume.Size
    target_bytes    = $targetBytes
    exit_status     = $status
    partial_bytes   = $partialBytes
} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $reportDir 'summary.json')
