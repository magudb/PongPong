param(
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$Target,
    [Parameter(Mandatory=$true)][string]$ExpectedSha,
    [Parameter(Mandatory=$true)][string]$Result,
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$stage = $null
$moved = $false
$installed = $false
try {
    $Target = [IO.Path]::GetFullPath($Target)
    if ((Split-Path -Leaf $Target) -cne 'Traetoppen' -or !(Test-Path -LiteralPath (Join-Path $Target 'Traetoppen.exe'))) { throw 'Invalid installation folder' }
    if ((Get-Item -LiteralPath $Target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installation is a symbolic link' }
    if ($ExpectedSha -cnotmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedSha) { throw 'Update checksum mismatch' }
    $stage = Join-Path (Split-Path -Parent $Target) ('.Traetoppen-update.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $package = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $package.Entries) {
            if (!$entry.FullName.StartsWith('Traetoppen/', [StringComparison]::Ordinal) -or $entry.FullName -match '(^|/)\.\.(/|$)|\\|:' ) { throw 'Unsafe update archive path' }
        }
    } finally { $package.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $stage)
    $replacement = Join-Path $stage 'Traetoppen'
    if (!(Test-Path -LiteralPath (Join-Path $replacement 'Traetoppen.exe')) -or !(Test-Path -LiteralPath (Join-Path $replacement 'Traetoppen.pck'))) { throw 'Incomplete update package' }
    # Setup installs this locally; release ZIPs contain only game files.
    # Carry it through the atomic replacement so Apps & Features keeps working.
    $uninstaller = Join-Path $Target 'Uninstall.exe'
    if (Test-Path -LiteralPath $uninstaller -PathType Leaf) {
        Copy-Item -LiteralPath $uninstaller -Destination (Join-Path $replacement 'Uninstall.exe')
    }
    [IO.File]::WriteAllText($Result + '.ready', 'ready')
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if ($ParentProcessId -eq 0 -or !(Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($ParentProcessId -ne 0 -and (Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue)) { throw 'The game did not exit' }
    $backup = Join-Path $stage 'previous'
    Move-Item -LiteralPath $Target -Destination $backup
    $moved = $true
    Move-Item -LiteralPath $replacement -Destination $Target
    if (!$NoLaunch) { Start-Process -FilePath (Join-Path $Target 'Traetoppen.exe') -WorkingDirectory $Target }
    @{status='installed'} | ConvertTo-Json -Compress | Set-Content -LiteralPath $Result -Encoding UTF8
    $installed = $true
    $registration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Traetoppen'
    $packageName = [IO.Path]::GetFileName($Archive)
    if ($packageName -cmatch '^Traetoppen-v((?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8}))-windows\.zip$') {
        $version = $Matches[1]
        $entry = Get-ItemProperty -LiteralPath $registration -ErrorAction SilentlyContinue
        if ($entry -and $entry.InstallLocation -ieq $Target) {
            Set-ItemProperty -LiteralPath $registration -Name DisplayVersion -Value $version -ErrorAction SilentlyContinue
        }
    }
} catch {
    if ($moved) {
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
        Move-Item -LiteralPath $backup -Destination $Target
        if (!$NoLaunch) { Start-Process -FilePath (Join-Path $Target 'Traetoppen.exe') -WorkingDirectory $Target }
    }
    @{status='failed'; detail=$_.Exception.Message} | ConvertTo-Json -Compress | Set-Content -LiteralPath $Result -Encoding UTF8
    Write-Error $_
    exit 1
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage) -and ($installed -or !$moved -or (Test-Path -LiteralPath $Target))) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
