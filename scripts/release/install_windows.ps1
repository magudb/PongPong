param(
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$Target,
    [Parameter(Mandatory=$true)][string]$ExpectedSha,
    [Parameter(Mandatory=$true)][string]$Result,
    [switch]$NoLaunch
)
# The result file always ends as {"status":"installed|rolled_back|failed","reason":"..."}: the game reads a
# failure while it waits for "ready", and the next start of the game reports the outcome of the swap.
$ErrorActionPreference = 'Stop'
$stage = $null
$reason = 'arguments'
$ready = $false
$moved = $false
$installed = $false
$restored = $false
function Write-Result([string]$status, [string]$why) {
    [ordered]@{status=$status; reason=$why} | ConvertTo-Json -Compress | Set-Content -LiteralPath $Result -Encoding UTF8
}
function Start-Game {
    if (!$NoLaunch) { Start-Process -FilePath (Join-Path $Target 'Traetoppen.exe') -WorkingDirectory $Target }
}
function Test-ParentRunning {
    return $ParentProcessId -ne 0 -and [bool](Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue)
}
try {
    $reason = 'folder'
    $Target = [IO.Path]::GetFullPath($Target)
    if ((Split-Path -Leaf $Target) -cne 'Traetoppen' -or !(Test-Path -LiteralPath (Join-Path $Target 'Traetoppen.exe'))) { throw 'Invalid installation folder' }
    if ((Get-Item -LiteralPath $Target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installation is a symbolic link' }
    $reason = 'checksum'
    if ($ExpectedSha -cnotmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedSha) { throw 'Update checksum mismatch' }
    $reason = 'folder'
    $stage = Join-Path (Split-Path -Parent $Target) ('.Traetoppen-update.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    $reason = 'package'
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
    # Windows locks a process's working directory. Start menu launches inherit
    # the game directory; leave it in both PowerShell and the OS before swapping.
    $installationParent = Split-Path -Parent $Target
    Set-Location -LiteralPath $installationParent
    [Environment]::CurrentDirectory = $installationParent
    [IO.File]::WriteAllText($Result + '.ready', 'ready')
    $ready = $true
    $reason = 'game_running'
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if (!(Test-ParentRunning)) { break }
        Start-Sleep -Milliseconds 500
    }
    if (Test-ParentRunning) { throw 'The game did not exit' }
    $reason = 'locked'
    $backup = Join-Path $stage 'previous'
    # Defender and the search indexer briefly hold files of a process that has just exited.
    # Rename the whole directory on the same volume. Move-Item can fall back to moving
    # individual files when a file is locked, leaving a partial backup that retries nest into.
    for ($attempt = 0; ; $attempt++) {
        try {
            [IO.Directory]::Move($Target, $backup)
            break
        } catch {
            if ($attempt -ge 5) { throw }
            Start-Sleep -Milliseconds (250 * [Math]::Pow(2, $attempt))
        }
    }
    $moved = $true
    [IO.Directory]::Move($replacement, $Target)
    # The outcome is written before the new build starts, so a failed write never rolls back a running game.
    $reason = 'unknown'
    Write-Result 'installed' ''
    $reason = 'launch'
    Start-Game
    $installed = $true
    try {
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
        # The new version is installed and running; a stale Apps & Features version is cosmetic.
    }
} catch {
    $failure = $_
    if ($moved -and !$installed) {
        try {
            if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
            [IO.Directory]::Move($backup, $Target)
            $restored = $true
        } catch {
            $reason = 'restore'
        }
    }
    try { Write-Result $(if ($restored) { 'rolled_back' } else { 'failed' }) $reason } catch {}
    # After "ready" the game has quit: bring the previous (or unchanged) installation back.
    if ($ready -and ($restored -or !$moved) -and !(Test-ParentRunning)) {
        try { Start-Game } catch {}
    }
    [Console]::Error.WriteLine($failure)
    exit 1
} finally {
    # Keep the stage when it still holds the only copy of the previous installation.
    if ($stage -and (Test-Path -LiteralPath $stage) -and ($installed -or $restored -or !$moved)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
