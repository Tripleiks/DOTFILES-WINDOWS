#requires -Version 5.1
<#
.SYNOPSIS
    Installs everything needed for the Ultimate PowerShell Profile, then
    wires the profile in.

.DESCRIPTION
    This is the one-shot installer. In plain English it does seven things:
      1. Sets two environment variables that opt out of telemetry
         (POWERSHELL_TELEMETRY_OPTOUT and DOTNET_CLI_TELEMETRY_OPTOUT).
      2. Uses winget to install the prompt (oh-my-posh), zoxide, and a
         handful of modern command-line tools (eza, bat, ripgrep, fd,
         fzf, delta, lazygit, difftastic, gsudo, bottom, gh, jq, yq,
         dust, duf, xh, glow, hyperfine, tldr). Skips anything you
         already have.
      3. Installs the JetBrains Mono Nerd Font so prompt icons render.
      4. Installs the core PowerShell modules used by the profile
         (PSReadLine, Terminal-Icons, posh-git, PSFzf).
      5. Installs the M365 / Azure / hybrid admin modules from PSGallery
         (Microsoft.Graph, Az, ExchangeOnlineManagement, MicrosoftTeams,
         Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell,
         PSWindowsUpdate, ImportExcel). These are large - skip with
         -NoAdminModules if not needed.
      6. When running elevated, installs the RSAT capabilities for
         Active Directory, DNS, DHCP, Group Policy, and Server Manager
         using Add-WindowsCapability. Required to manage AD / hybrid
         environments from this workstation.
      7. Runs install.ps1 to wire the profile into your PowerShell paths.

    The installer is idempotent - re-running it is safe. Anything already
    installed is detected and skipped.

    After it finishes, open a new PowerShell window (or run `reload` in an
    existing one) to load the profile.

    Note: AzureAD and MSOnline are NOT installed - they are deprecated by
    Microsoft and replaced by Microsoft.Graph. Use Microsoft.Graph instead.

.PARAMETER Minimal
    Skip the modern CLI tools (eza, bat, ripgrep, fd, fzf, delta, gsudo, gh)
    AND the enterprise admin modules AND the RSAT capabilities. You'll still
    get the prompt, zoxide, PSReadLine, Terminal-Icons, and the font.

.PARAMETER SkipFont
    Don't install any Nerd Fonts. Use if you already have one installed,
    or you manage fonts via another channel.

.PARAMETER Fonts
    Nerd Font families to install (user scope, via `oh-my-posh font install`).
    Defaults to the common five: JetBrainsMono, FiraCode, Meslo, CascadiaCode,
    Hack. Pass an empty array (-Fonts @()) to skip all without disabling
    -SkipFont. Examples:
        -Fonts JetBrainsMono           # only that one
        -Fonts JetBrainsMono,FiraCode  # only two
        -Fonts @()                     # none (same as -SkipFont)

.PARAMETER NoAdmin
    Avoid actions that need administrator rights. Telemetry opt-out is
    written at user scope instead of machine scope, and RSAT capabilities
    are skipped (they require elevation).

.PARAMETER NoAdminModules
    Skip the M365 / Azure / hybrid admin PowerShell modules (Microsoft.Graph,
    Az, ExchangeOnlineManagement, MicrosoftTeams, SharePoint, PnP, etc.).
    These can total several gigabytes of disk and take many minutes - omit
    this flag if you actually administer M365/Azure, otherwise use it.

.PARAMETER NoRSAT
    Skip the RSAT capabilities (Active Directory, DNS, DHCP, Group Policy,
    Server Manager). Use on personal machines that won't be managing AD.

.EXAMPLE
    pwsh -File .\setup.ps1
    The full install for an admin workstation. Includes M365 / Azure
    modules and (if elevated) RSAT capabilities.

.EXAMPLE
    pwsh -File .\setup.ps1 -NoAdminModules -NoRSAT
    Same as the full install but skip the heavyweight enterprise modules.
    Good for personal / dev laptops.

.EXAMPLE
    pwsh -File .\setup.ps1 -Minimal -SkipFont
    Just the prompt and history goodies. No modern CLI tools, no admin
    modules, no RSAT, no font.
#>
[CmdletBinding()]
param(
    [switch]$Minimal,
    [switch]$SkipFont,
    [switch]$NoAdmin,
    [switch]$NoAdminModules,
    [switch]$NoRSAT,
    [string[]]$Fonts = @('JetBrainsMono','FiraCode','Meslo','CascadiaCode','Hack')
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
    'Starship.Starship',            # primary prompt engine (Dracula config in themes\)
    'JanDeDobbeleer.OhMyPosh',      # fallback prompt
    'ajeetdsouza.zoxide',
    'Fastfetch-cli.Fastfetch'       # neofetch successor - shown on shell start
)
$modernCli = @(
    # Search / view / list
    'junegunn.fzf',                 # fuzzy finder (Ctrl+T / Ctrl+R via PSFzf)
    'sharkdp.bat',                  # syntax-highlighted `cat`
    'eza-community.eza',            # colourful `ls`/`tree`
    'BurntSushi.ripgrep.MSVC',      # fast `grep`
    'sharkdp.fd',                   # fast `find`

    # Git ecosystem
    'dandavison.delta',             # colourful diff pager
    'JesseDuffield.lazygit',        # full-screen git TUI (alias: lg)
    'Wilfred.difftastic',           # syntax-aware diff (difft)

    # System & elevation
    'gerardog.gsudo',               # sudo-like elevation
    'Clement.bottom',               # btop/htop-style monitor (alias: top -> btm)

    # GitHub
    'GitHub.cli',                   # gh

    # JSON / YAML
    'jqlang.jq',                    # JSON query
    'MikeFarah.yq',                 # YAML query (also handles JSON)

    # Disk usage (du / df get auto-upgraded if these are present)
    'bootandy.dust',
    'muesli.duf',

    # HTTP / docs / measurement
    'ducaale.xh',                   # friendlier curl / Invoke-WebRequest
    'charmbracelet.glow',           # render markdown in the terminal
    'sharkdp.hyperfine',            # benchmark commands

    # Quick command examples
    'tldr-pages.tlrc',              # `tldr <cmd>` cheat sheets

    # TUI file manager
    'sxyazi.yazi'                   # terminal file manager (profile adds `y` cd-on-exit wrapper)
)

Write-Step 'Installing winget packages'
foreach ($pkg in $essentials)             { Install-WingetPackage -Id $pkg }
if (-not $Minimal) {
    foreach ($pkg in $modernCli)          { Install-WingetPackage -Id $pkg }
}

# -----------------------------------------------------------------------------
# 3. Nerd Fonts via oh-my-posh. Idempotent: skips families already installed
#    in the user-scope Windows font folder.
# -----------------------------------------------------------------------------
function Test-NerdFontInstalled {
    param([string]$Family)
    $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (-not (Test-Path $userFontDir)) { return $false }

    # Nerd Fonts renames some families on install (trademark / disambiguation).
    # Map the install argument to a regex that matches the actual filenames.
    $pattern = switch -Exact ($Family) {
        'CascadiaCode' { 'CaskaydiaCove|CaskaydiaMono' }
        'CascadiaMono' { 'CaskaydiaMono' }
        'SourceCodePro' { 'SourceCodePro|SauceCodePro' }
        default        { [regex]::Escape($Family) }
    }
    # Match files like "JetBrainsMonoNerdFont-Regular.ttf" or "JetBrainsMonoNL Nerd Font Mono-Regular.ttf".
    $found = Get-ChildItem $userFontDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "($pattern).*Nerd" }
    [bool]$found
}

if (-not $SkipFont -and $Fonts.Count -gt 0) {
    if (-not (Has-Command 'oh-my-posh')) {
        Write-Warn 'oh-my-posh not on PATH yet — re-run setup.ps1 after restarting your shell to install fonts.'
    } else {
        foreach ($family in $Fonts) {
            if (Test-NerdFontInstalled -Family $family) {
                Write-Skip "$family Nerd Font already installed"
                continue
            }
            Write-Step "Installing $family Nerd Font (user scope, headless)"
            try {
                # --headless disables the TUI so the install is non-interactive.
                # oh-my-posh installs at user scope by default; no admin needed.
                oh-my-posh font install $family --headless 2>&1 | Out-Null
                if (Test-NerdFontInstalled -Family $family) {
                    Write-Ok "$family Nerd Font installed"
                } else {
                    Write-Warn "$family install reported no error but font not found in user fonts dir"
                }
            } catch {
                Write-Warn "$family install failed: $($_.Exception.Message)"
            }
        }
    }
}

# -----------------------------------------------------------------------------
# 4. PSGallery modules - core profile modules.
# -----------------------------------------------------------------------------
Write-Step 'Installing core PowerShell modules'
Install-PSModule -Name PSReadLine      -MinimumVersion '2.2.0'
Install-PSModule -Name Terminal-Icons
if (-not $Minimal) {
    Install-PSModule -Name posh-git
    Install-PSModule -Name PSFzf
}

# -----------------------------------------------------------------------------
# 5. Enterprise admin modules - M365 / Azure / hybrid.
#
# These are large. Microsoft.Graph and Az each pull dozens of submodules.
# Skip with -Minimal or -NoAdminModules if not actually administering
# M365 / Azure / hybrid environments.
# -----------------------------------------------------------------------------
if ((-not $Minimal) -and (-not $NoAdminModules)) {
    Write-Step 'Installing M365 / Azure / hybrid admin modules (LARGE - may take several minutes)'
    Write-Skip 'AzureAD and MSOnline are deprecated by Microsoft - using Microsoft.Graph instead'

    # M365 / Graph - modern replacement for AzureAD + MSOnline.
    Install-PSModule -Name Microsoft.Graph

    # Exchange Online, Security & Compliance, EOP, MDO.
    Install-PSModule -Name ExchangeOnlineManagement

    # Teams admin.
    Install-PSModule -Name MicrosoftTeams

    # SharePoint Online admin.
    Install-PSModule -Name Microsoft.Online.SharePoint.PowerShell

    # PnP (M365 / SharePoint / Teams / Graph - very widely used in the community).
    Install-PSModule -Name PnP.PowerShell

    # Azure.
    Install-PSModule -Name Az

    # Windows Update management from PowerShell.
    Install-PSModule -Name PSWindowsUpdate

    # Excel reporting without needing Excel installed.
    Install-PSModule -Name ImportExcel
} else {
    Write-Skip 'Skipping enterprise admin modules (use no flags / drop -NoAdminModules to install them)'
}

# -----------------------------------------------------------------------------
# 6. RSAT capabilities - Active Directory / DNS / DHCP / Group Policy.
#
# Required to manage AD, DNS, DHCP, GPOs, and other server roles from this
# workstation. Installed via Add-WindowsCapability (needs elevation).
# -----------------------------------------------------------------------------
if ((-not $Minimal) -and (-not $NoRSAT)) {
    $isAdmin = Test-Admin
    if ((-not $isAdmin) -or $NoAdmin) {
        Write-Warn 'RSAT install needs admin (re-run elevated) or -NoAdmin was passed - skipping.'
    } else {
        $isServerSku = $false
        try {
            $isServerSku = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).ProductType -ne 1
        } catch {}

        if ($isServerSku) {
            Write-Warn 'Server SKU detected. Use `Install-WindowsFeature RSAT-*` instead - skipping client-style RSAT.'
        } else {
            Write-Step 'Installing RSAT capabilities (AD, DNS, DHCP, GroupPolicy, ServerManager)'
            $rsatCapabilities = @(
                'Rsat.ActiveDirectory.DS-LDS.Tools',
                'Rsat.Dns.Tools',
                'Rsat.DHCP.Tools',
                'Rsat.GroupPolicy.Management.Tools',
                'Rsat.ServerManager.Tools',
                'Rsat.CertificateServices.Tools',
                'Rsat.FileServices.Tools'
            )
            foreach ($cap in $rsatCapabilities) {
                try {
                    $match = Get-WindowsCapability -Online -Name "$cap*" -ErrorAction Stop |
                        Select-Object -First 1
                    if (-not $match) { Write-Warn "$cap not available on this OS"; continue }
                    if ($match.State -eq 'Installed') { Write-Skip "$cap already installed"; continue }
                    Add-WindowsCapability -Online -Name $match.Name -ErrorAction Stop | Out-Null
                    Write-Ok "$cap installed"
                } catch {
                    Write-Warn "$cap install failed: $($_.Exception.Message)"
                }
            }
        }
    }
} else {
    Write-Skip 'Skipping RSAT capabilities (per -Minimal / -NoRSAT)'
}

# -----------------------------------------------------------------------------
# 7. Wire the profile into PS 5.1 and PS 7 profile paths.
# -----------------------------------------------------------------------------
$installScript = Join-Path $PSScriptRoot 'install.ps1'
if (Test-Path $installScript) {
    Write-Step 'Wiring profile via install.ps1'
    & $installScript
} else {
    Write-Warn "install.ps1 not found next to setup.ps1 — wire the profile manually."
}

# -----------------------------------------------------------------------------
# 8. Link auxiliary tool configs (Yazi, etc.). Each lives in a sibling folder
#    with its own install.ps1. Skipped silently if the folder isn't present.
# -----------------------------------------------------------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot
$yaziInstall = Join-Path $repoRoot 'Yazi\install.ps1'
if (Test-Path $yaziInstall) {
    Write-Step 'Linking Yazi config via Yazi\install.ps1'
    try { & $yaziInstall } catch { Write-Warn "Yazi install reported: $($_.Exception.Message)" }
}

Write-Host ''
Write-Host '✔ Setup complete.' -ForegroundColor Green
Write-Host '  Restart your shell (or run `reload`) to pick up everything.' -ForegroundColor Gray
Write-Host '  Set Windows Terminal font to "JetBrainsMono Nerd Font" for icons.' -ForegroundColor Gray
