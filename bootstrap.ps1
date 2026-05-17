#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot installer for DOTFILES-WINDOWS. Installs git (if missing),
    clones the repo, and runs setup.ps1.

.DESCRIPTION
    Designed to be run as a single line from a fresh PowerShell window:

        irm https://raw.githubusercontent.com/Tripleiks/DOTFILES-WINDOWS/main/bootstrap.ps1 | iex

    For flag pass-through (e.g. skip enterprise admin modules):

        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Tripleiks/DOTFILES-WINDOWS/main/bootstrap.ps1))) -NoAdminModules

    Steps:
        1. Set execution policy to Bypass for this process.
        2. Install git via winget if missing.
        3. Clone (or git pull) DOTFILES-WINDOWS into
           %USERPROFILE%\GitHub\DOTFILES-WINDOWS.
        4. Run PowerShell\setup.ps1 with any pass-through flags.

    Safe to re-run: every step is idempotent.

.PARAMETER Destination
    Where to clone the repo. Defaults to %USERPROFILE%\GitHub\DOTFILES-WINDOWS.

.PARAMETER Branch
    Git branch to use. Defaults to 'main'.

.PARAMETER Minimal
    Pass-through to setup.ps1 — skip modern CLI tools, enterprise modules, RSAT.

.PARAMETER SkipFont
    Pass-through to setup.ps1 — skip JetBrains Mono Nerd Font install.

.PARAMETER NoAdmin
    Pass-through to setup.ps1 — set telemetry env vars at user scope only,
    skip RSAT.

.PARAMETER NoAdminModules
    Pass-through to setup.ps1 — skip the heavy M365/Azure/Graph modules.

.PARAMETER NoRSAT
    Pass-through to setup.ps1 — skip RSAT capability installs.
#>
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:USERPROFILE 'GitHub\DOTFILES-WINDOWS'),
    [string]$RepoUrl    = 'https://github.com/Tripleiks/DOTFILES-WINDOWS.git',
    [string]$Branch     = 'main',
    [switch]$Minimal,
    [switch]$SkipFont,
    [switch]$NoAdmin,
    [switch]$NoAdminModules,
    [switch]$NoRSAT
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "    [!] $m" -ForegroundColor Yellow }
function Test-Cmd   { param([string]$n) [bool](Get-Command $n -ErrorAction SilentlyContinue) }

# Run with relaxed policy in this process so .ps1 scripts can execute.
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch {}

Write-Host ''
Write-Step 'DOTFILES-WINDOWS bootstrap'
Write-Host "    Destination: $Destination" -ForegroundColor DarkGray
Write-Host "    Repo:        $RepoUrl ($Branch)" -ForegroundColor DarkGray
Write-Host ''

# 1) git ----------------------------------------------------------------------
if (Test-Cmd 'git') {
    Write-Ok "git $((& git --version) -replace '^git version ','') already installed"
} else {
    Write-Step 'Installing git via winget'
    if (-not (Test-Cmd 'winget')) {
        throw 'winget not found. Install App Installer from the Microsoft Store, or install git manually from https://git-scm.com/, then re-run this bootstrap.'
    }
    winget install --id Git.Git --source winget --silent `
                   --accept-source-agreements --accept-package-agreements | Out-Null

    # Refresh PATH from the registry so the just-installed git is visible
    # in *this* process without restarting the shell.
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')

    if (-not (Test-Cmd 'git')) {
        throw 'git install reported success but git is still not on PATH. Open a fresh PowerShell window and re-run this bootstrap.'
    }
    Write-Ok 'git installed'
}

# 2) Clone or pull ------------------------------------------------------------
$gitDir = Join-Path $Destination '.git'
if (Test-Path $gitDir) {
    Write-Step "Updating existing repo at $Destination"
    Push-Location $Destination
    try {
        git fetch origin --prune
        git checkout $Branch
        git pull --ff-only origin $Branch
        Write-Ok 'pulled latest'
    } finally { Pop-Location }
} else {
    Write-Step "Cloning $RepoUrl to $Destination"
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    git clone --branch $Branch $RepoUrl $Destination
    Write-Ok 'cloned'
}

# 3) setup.ps1 ----------------------------------------------------------------
$setup = Join-Path $Destination 'PowerShell\setup.ps1'
if (-not (Test-Path $setup)) {
    throw "Could not find setup.ps1 at $setup — repo layout may have changed."
}

# Collect only the switches the caller actually set, so setup.ps1's defaults stay in effect.
$setupArgs = @{}
foreach ($name in 'Minimal','SkipFont','NoAdmin','NoAdminModules','NoRSAT') {
    if ($PSBoundParameters.ContainsKey($name)) { $setupArgs[$name] = $PSBoundParameters[$name] }
}

Write-Step "Running setup.ps1 $(if ($setupArgs.Count) { '(' + (($setupArgs.GetEnumerator() | ForEach-Object { "-$($_.Key)" }) -join ' ') + ')' })"
& $setup @setupArgs

Write-Host ''
Write-Host 'Bootstrap complete.' -ForegroundColor Green
Write-Host "  Repo at: $Destination" -ForegroundColor DarkGray
Write-Host '  Open a new PowerShell window to load the profile.' -ForegroundColor DarkGray
Write-Host '  Set Windows Terminal font to "JetBrainsMono Nerd Font" for icons.' -ForegroundColor DarkGray
