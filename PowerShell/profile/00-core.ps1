# =============================================================================
# 00-core.ps1 - Foundation used by every other module
#
# WHAT THIS DOES
#   Sets up the basics every other module relies on:
#     - PowerShell version & platform flags ($IsPS7, $IsPS51, $IsWindows)
#     - UTF-8 everywhere, so emojis and umlauts don't get corrupted
#     - Telemetry opt-outs for PowerShell and .NET
#     - Test-Command         -> is this tool installed? (true/false)
#     - Register-DeferredLoad -> run this AFTER the first prompt (faster startup)
#     - Path roots: $DOTFILES_ROOT, $GITHUB_ROOT
#
#   Nothing user-facing here. This is plumbing for the files loaded after.
# =============================================================================

# Version & platform flags (PS 5.1 lacks $IsWindows / $IsMacOS / $IsLinux).
$Global:IsPS7   = $PSVersionTable.PSVersion.Major -ge 6
$Global:IsPS51  = $PSVersionTable.PSVersion.Major -eq 5
if (-not (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:IsWindows = $true   # PS 5.1 = Windows-only
}

# UTF-8 everywhere — fixes mojibake in pipes & Unicode in output.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ($IsWindows) {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
}
$PSDefaultParameterValues['Out-File:Encoding']         = 'utf8'
$PSDefaultParameterValues['*:Encoding']                = 'utf8'

# Opt out of telemetry (also handled in setup.ps1 at machine scope).
$env:POWERSHELL_TELEMETRY_OPTOUT     = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT     = '1'

# -----------------------------------------------------------------------------
# Helpers used by other profile modules.
# -----------------------------------------------------------------------------

# Test-Command — true if a command is on PATH or defined in-session.
function Global:Test-Command {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Register-DeferredLoad — schedule work to run on first PowerShell idle.
# OnIdle handlers cannot mutate session state, so we use a one-shot prompt wrap
# (see profile/90-deferred.ps1 for the actual mechanism).
$Global:__DeferredActions = [System.Collections.Generic.List[scriptblock]]::new()
function Global:Register-DeferredLoad {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock]$Action)
    $Global:__DeferredActions.Add($Action)
}

# Path roots — adjust these to taste.
$Global:DOTFILES_ROOT = if ($env:DOTFILES_ROOT) { $env:DOTFILES_ROOT }
                       else { Split-Path -Parent $env:PROFILE_ROOT }
$Global:GITHUB_ROOT   = if ($env:GITHUB_ROOT) { $env:GITHUB_ROOT }
                       elseif (Test-Path 'C:\GitHub') { 'C:\GitHub' }
                       else { Join-Path $HOME 'GitHub' }
