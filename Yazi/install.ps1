#Requires -Version 5.1
<#
.SYNOPSIS
    Symlinks the Yazi config files in this repo into %APPDATA%\yazi\config\.

.DESCRIPTION
    In plain English:
        Tells Yazi "use the config files in this repo as your config." After
        running, editing Yazi\config\yazi.toml in the repo takes effect the
        next time Yazi starts — no copy step needed.

    What it actually does:
        Creates %APPDATA%\yazi\config\ if it doesn't exist, then creates a
        symbolic link for each of yazi.toml, keymap.toml, theme.toml pointing
        back at the matching file in this repo's Yazi\config\ folder. Any
        pre-existing real file at the target is backed up to *.bak.<timestamp>
        before being replaced.

    Idempotency:
        Re-running is safe. If the link already points at the repo file the
        script reports it and moves on.

    Symlink requirements on Windows:
        Creating symlinks needs either administrator rights OR Developer Mode
        (Settings → Privacy & security → For developers → Developer Mode).
        If neither is enabled the script reports each failure and stops short
        of falling back to copying — copying would silently break the
        edit-in-repo model and is rarely what you want.

    The script does NOT install Yazi itself. Run PowerShell\setup.ps1 first
    (or `winget install sxyazi.yazi`).

.PARAMETER Force
    Replace existing target files without making a .bak backup.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "    [ok] $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "    [=]  $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Msg) Write-Host "    [!]  $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "    [x]  $Msg" -ForegroundColor Red }

$repoConfigDir = Join-Path $PSScriptRoot 'config'
if (-not (Test-Path $repoConfigDir)) {
    throw "Repo config directory not found: $repoConfigDir"
}

$destDir = Join-Path $env:APPDATA 'yazi\config'
if (-not (Test-Path $destDir)) {
    Write-Step "Creating $destDir"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# The files we own. Anything else in %APPDATA%\yazi\ (plugins, flavors, etc.)
# is left alone.
$files = @('yazi.toml', 'keymap.toml', 'theme.toml')

Write-Step "Linking Yazi config from $repoConfigDir"
Write-Host  "         into $destDir" -ForegroundColor DarkGray

$failed = 0
foreach ($name in $files) {
    $src  = Join-Path $repoConfigDir $name
    $dest = Join-Path $destDir       $name

    if (-not (Test-Path $src)) {
        Write-Warn "$name not present in repo - skipping"
        continue
    }

    if (Test-Path $dest) {
        $item = Get-Item -LiteralPath $dest -Force
        $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)

        if ($isLink) {
            # Resolve the link target. Target is absolute on newer PS / Windows.
            $target = $null
            try { $target = $item.Target } catch {}
            if (-not $target) { try { $target = (Get-Item -LiteralPath $dest).LinkTarget } catch {} }

            if ($target -and ((Resolve-Path -LiteralPath $target -ErrorAction SilentlyContinue).Path -eq (Resolve-Path -LiteralPath $src).Path)) {
                Write-Skip "$name already linked"
                continue
            } else {
                Write-Warn "$name is a symlink pointing elsewhere ($target) - replacing"
                try { Remove-Item -LiteralPath $dest -Force } catch { Write-Err "could not remove existing link: $($_.Exception.Message)"; $failed++; continue }
            }
        } else {
            if ($Force) {
                Write-Warn "$name exists as a real file - overwriting (no backup, -Force)"
            } else {
                $ts  = Get-Date -Format 'yyyyMMdd-HHmmss'
                $bak = "$dest.bak.$ts"
                Copy-Item -LiteralPath $dest -Destination $bak -Force
                Write-Warn "$name exists as a real file - backed up to $bak"
            }
            try { Remove-Item -LiteralPath $dest -Force } catch { Write-Err "could not remove existing file: $($_.Exception.Message)"; $failed++; continue }
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src -Force | Out-Null
        Write-Ok "$name -> $src"
    } catch {
        $failed++
        Write-Err "$name link failed: $($_.Exception.Message)"
        Write-Host "         Enable Developer Mode (Settings > Privacy & security > For developers)" -ForegroundColor DarkGray
        Write-Host "         or re-run this script from an elevated PowerShell window." -ForegroundColor DarkGray
    }
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "Yazi config link finished with $failed failure(s)." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host 'Yazi config linked.' -ForegroundColor Green
    if (Get-Command yazi -ErrorAction SilentlyContinue) {
        Write-Host '  Start it with `yazi` or `y` (the shell wrapper added by the profile).' -ForegroundColor DarkGray
    } else {
        Write-Host '  Yazi is not on PATH yet - run PowerShell\setup.ps1 or `winget install sxyazi.yazi`.' -ForegroundColor DarkGray
    }
}
