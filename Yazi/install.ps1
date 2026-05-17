#Requires -Version 5.1
<#
.SYNOPSIS
    Symlinks the Yazi config files and vendored plugins from this repo into
    %APPDATA%\yazi\ so edits in the repo apply on next yazi launch.

.DESCRIPTION
    In plain English:
        Tells Yazi "use the configs and plugins in this repo as your own."
        After running, editing Yazi\config\yazi.toml or Yazi\plugins\*\main.lua
        in the repo takes effect on the next yazi launch — no copy step.

    What it links:
        - Each file in Yazi\config\ -> %APPDATA%\yazi\config\<file>
        - Each subdir of Yazi\plugins\ -> %APPDATA%\yazi\config\plugins\<subdir>

        Note: yazi looks for plugins under the CONFIG directory
        (%APPDATA%\yazi\config\plugins\), not as a sibling of it.

        Plugins are linked as whole directories, so any file inside the
        plugin (main.lua, README, assets) comes along automatically.

    Idempotency:
        Re-running is safe. Existing symlinks pointing at the repo are
        reported and left alone. Real files/dirs at the target are backed
        up to *.bak.<timestamp> before being replaced.

    Symlink requirements on Windows:
        Creating symlinks needs administrator rights OR Developer Mode
        (Settings -> Privacy & security -> For developers -> Developer Mode).
        The script does NOT fall back to copying on failure — copying would
        silently break the edit-in-repo model.

    This script does NOT install Yazi or chafa. Run PowerShell\setup.ps1
    first (or `winget install sxyazi.yazi hpjansson.Chafa`).

.PARAMETER Force
    Replace existing target files/dirs without making a .bak backup.
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

# Symlink one source onto one destination. Returns $true on success,
# $false on failure. Backs up any pre-existing real file/dir at $Dest
# unless -Force is in effect.
function Link-One {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest,
        [Parameter(Mandatory)][string]$Label,
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warn "$Label`: source missing - $Source"
        return $false
    }

    if (Test-Path -LiteralPath $Dest) {
        $item = Get-Item -LiteralPath $Dest -Force
        $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)

        if ($isLink) {
            $target = $null
            try { $target = $item.Target }     catch {}
            if (-not $target) { try { $target = $item.LinkTarget } catch {} }

            if ($target) {
                $tgtResolved = (Resolve-Path -LiteralPath $target -ErrorAction SilentlyContinue).Path
                $srcResolved = (Resolve-Path -LiteralPath $Source).Path
                if ($tgtResolved -eq $srcResolved) {
                    Write-Skip "$Label already linked"
                    return $true
                }
            }
            Write-Warn "$Label`: symlink points elsewhere ($target) - replacing"
            try { Remove-Item -LiteralPath $Dest -Force -Recurse }
            catch { Write-Err "$Label`: cannot remove existing link - $($_.Exception.Message)"; return $false }
        } else {
            if ($Force) {
                Write-Warn "$Label exists as real file/dir - overwriting (no backup, -Force)"
            } else {
                $ts  = Get-Date -Format 'yyyyMMdd-HHmmss'
                $bak = "$Dest.bak.$ts"
                Copy-Item -LiteralPath $Dest -Destination $bak -Force -Recurse
                Write-Warn "$Label exists as real file/dir - backed up to $bak"
            }
            try { Remove-Item -LiteralPath $Dest -Force -Recurse }
            catch { Write-Err "$Label`: cannot remove existing item - $($_.Exception.Message)"; return $false }
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Source -Force | Out-Null
        Write-Ok "$Label -> $Source"
        return $true
    } catch {
        Write-Err "$Label link failed: $($_.Exception.Message)"
        Write-Host "         Enable Developer Mode (Settings > Privacy & security > For developers)" -ForegroundColor DarkGray
        Write-Host "         or re-run this script from an elevated PowerShell window." -ForegroundColor DarkGray
        return $false
    }
}

# --- Resolve repo locations and ensure %APPDATA%\yazi exists ----------------

$repoConfigDir  = Join-Path $PSScriptRoot 'config'
$repoPluginsDir = Join-Path $PSScriptRoot 'plugins'
if (-not (Test-Path $repoConfigDir)) {
    throw "Repo config directory not found: $repoConfigDir"
}

$destConfigDir  = Join-Path $env:APPDATA 'yazi\config'
$destPluginsDir = Join-Path $destConfigDir 'plugins'

foreach ($d in @($destConfigDir, $destPluginsDir)) {
    if (-not (Test-Path $d)) {
        Write-Step "Creating $d"
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

$failed = 0

# --- 1. Config files --------------------------------------------------------
Write-Step "Linking config files: $repoConfigDir -> $destConfigDir"
$configFiles = @('yazi.toml', 'keymap.toml', 'theme.toml')
foreach ($name in $configFiles) {
    $src  = Join-Path $repoConfigDir $name
    $dest = Join-Path $destConfigDir $name
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Skip "$name not present in repo"
        continue
    }
    if (-not (Link-One -Source $src -Dest $dest -Label $name -Force:$Force)) { $failed++ }
}

# --- 2. Plugin directories --------------------------------------------------
if (Test-Path $repoPluginsDir) {
    Write-Step "Linking plugins: $repoPluginsDir -> $destPluginsDir"
    $pluginDirs = @(Get-ChildItem -LiteralPath $repoPluginsDir -Directory -ErrorAction SilentlyContinue)
    if ($pluginDirs.Count -eq 0) {
        Write-Skip "no plugin directories in repo"
    } else {
        foreach ($pd in $pluginDirs) {
            $src  = $pd.FullName
            $dest = Join-Path $destPluginsDir $pd.Name
            if (-not (Link-One -Source $src -Dest $dest -Label $pd.Name -Force:$Force)) { $failed++ }
        }
    }
} else {
    Write-Skip "no plugins directory in repo - skipping plugin links"
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "Yazi link finished with $failed failure(s)." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host 'Yazi config + plugins linked.' -ForegroundColor Green
    if (Get-Command yazi -ErrorAction SilentlyContinue) {
        Write-Host '  Start it with `yazi` or `y` (the shell wrapper added by the profile).' -ForegroundColor DarkGray
    } else {
        Write-Host '  Yazi is not on PATH yet - run PowerShell\setup.ps1 or `winget install sxyazi.yazi`.' -ForegroundColor DarkGray
    }
}
