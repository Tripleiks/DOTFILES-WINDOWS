#requires -Version 5.1
<#
.SYNOPSIS
    Installs everything needed for the Ultimate PowerShell Profile, then
    wires the profile in.

.DESCRIPTION
    This is the one-shot installer. In plain English it does five things:
      1. Sets two environment variables that opt out of telemetry
         (POWERSHELL_TELEMETRY_OPTOUT and DOTNET_CLI_TELEMETRY_OPTOUT).
      2. Uses winget to install the prompt (oh-my-posh), zoxide, and a
         handful of modern command-line tools (eza, bat, ripgrep, fd,
         fzf, delta, gsudo, gh). Skips anything you already have.
      3. Installs the JetBrains Mono Nerd Font so prompt icons render.
      4. Installs PowerShell modules (PSReadLine, Terminal-Icons,
         posh-git, PSFzf) from PSGallery.
      5. Runs install.ps1 to wire the profile into your PowerShell paths.

    The installer is idempotent - re-running it is safe. Anything already
    installed is detected and skipped.

    After it finishes, open a new PowerShell window (or run `reload` in an
    existing one) to load the profile.

.PARAMETER Minimal
    Skip the modern CLI tools (eza, bat, ripgrep, fd, fzf, delta, gsudo, gh)
    and the optional modules (posh-git, PSFzf). You'll still get the prompt,
    zoxide, PSReadLine, Terminal-Icons, and the font.

.PARAMETER SkipFont
    Don't install the JetBrains Mono Nerd Font. Use if you already have a
    Nerd Font installed, or you manage fonts via another channel.

.PARAMETER NoAdmin
    Avoid actions that need administrator rights. Telemetry opt-out is
    written at user scope instead of machine scope.

.EXAMPLE
    pwsh -File .\setup.ps1
    The full install. Recommended for most people.

.EXAMPLE
    pwsh -File .\setup.ps1 -Minimal -SkipFont
    Just the prompt and history goodies. No modern CLI tools, no font.
#>
[CmdletBinding()]
param(
    [switch]$Minimal,
    [switch]$SkipFont,
    [switch]$NoAdmin
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Write-Step { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "    ✓ $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "    · $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Msg) Write-Host "    ! $Msg" -ForegroundColor Yellow }

function Test-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Has-Command { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Install-WingetPackage {
    param([string]$Id, [string]$Source = 'winget')
    if (-not (Has-Command 'winget')) { Write-Warn "winget not installed; skipping $Id"; return }
    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null |
        Select-String -Pattern $Id -SimpleMatch
    if ($installed) { Write-Skip "$Id already installed"; return }
    Write-Step "Installing $Id via winget"
    winget install --id $Id --exact --source $Source --silent `
                   --accept-package-agreements --accept-source-agreements |
        Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id installed" } else { Write-Warn "$Id install returned exit $LASTEXITCODE" }
}

function Install-PSModule {
    param([string]$Name, [string]$MinimumVersion)
    $existing = Get-Module -ListAvailable $Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($existing -and (-not $MinimumVersion -or $existing.Version -ge [version]$MinimumVersion)) {
        Write-Skip "$Name $($existing.Version) already installed"
        return
    }
    Write-Step "Installing PowerShell module: $Name"
    try {
        # Trust PSGallery once so subsequent installs are quiet.
        if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        $params = @{ Name = $Name; Scope = 'CurrentUser'; Force = $true; AllowClobber = $true }
        if ($MinimumVersion) { $params['MinimumVersion'] = $MinimumVersion }
        Install-Module @params
        Write-Ok "$Name installed"
    } catch {
        Write-Warn "$Name install failed: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 1. Telemetry opt-out (machine scope needs admin; user scope always works).
# -----------------------------------------------------------------------------
Write-Step 'Setting telemetry opt-out env vars'
if ((Test-Admin) -and (-not $NoAdmin)) {
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT','1','Machine')
    [Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT','1','Machine')
    Write-Ok 'Set at machine scope'
} else {
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT','1','User')
    [Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT','1','User')
    Write-Ok 'Set at user scope'
}

# -----------------------------------------------------------------------------
# 2. Winget packages.
# -----------------------------------------------------------------------------
$essentials = @(
    'JanDeDobbeleer.OhMyPosh',
    'ajeetdsouza.zoxide'
)
$modernCli = @(
    'junegunn.fzf',
    'sharkdp.bat',
    'eza-community.eza',
    'BurntSushi.ripgrep.MSVC',
    'sharkdp.fd',
    'dandavison.delta',
    'gerardog.gsudo',
    'GitHub.cli'
)

Write-Step 'Installing winget packages'
foreach ($pkg in $essentials)             { Install-WingetPackage -Id $pkg }
if (-not $Minimal) {
    foreach ($pkg in $modernCli)          { Install-WingetPackage -Id $pkg }
}

# -----------------------------------------------------------------------------
# 3. Nerd Font (JetBrainsMono) via oh-my-posh.
# -----------------------------------------------------------------------------
if (-not $SkipFont) {
    if (Has-Command 'oh-my-posh') {
        Write-Step 'Installing JetBrainsMono Nerd Font'
        try {
            oh-my-posh font install JetBrainsMono --user 2>$null
            Write-Ok 'JetBrainsMono Nerd Font installed (user scope)'
        } catch {
            Write-Warn "Font install failed: $($_.Exception.Message). Install manually from nerdfonts.com."
        }
    } else {
        Write-Warn 'oh-my-posh not on PATH yet — re-run setup.ps1 after restarting your shell to install the font.'
    }
}

# -----------------------------------------------------------------------------
# 4. PSGallery modules.
# -----------------------------------------------------------------------------
Write-Step 'Installing PowerShell modules'
Install-PSModule -Name PSReadLine      -MinimumVersion '2.2.0'
Install-PSModule -Name Terminal-Icons
if (-not $Minimal) {
    Install-PSModule -Name posh-git
    Install-PSModule -Name PSFzf
}

# -----------------------------------------------------------------------------
# 5. Wire the profile into PS 5.1 and PS 7 profile paths.
# -----------------------------------------------------------------------------
$installScript = Join-Path $PSScriptRoot 'install.ps1'
if (Test-Path $installScript) {
    Write-Step 'Wiring profile via install.ps1'
    & $installScript
} else {
    Write-Warn "install.ps1 not found next to setup.ps1 — wire the profile manually."
}

Write-Host ''
Write-Host '✔ Setup complete.' -ForegroundColor Green
Write-Host '  Restart your shell (or run `reload`) to pick up everything.' -ForegroundColor Gray
Write-Host '  Set Windows Terminal font to "JetBrainsMono Nerd Font" for icons.' -ForegroundColor Gray
