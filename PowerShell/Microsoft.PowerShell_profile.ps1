# =============================================================================
# Ultimate PowerShell Profile - entry point
#
# WHAT THIS FILE IS
#   The "front door" of the profile. When PowerShell starts, it ends up here,
#   and this file loads every other piece in order.
#
#   The actual content lives in the `profile\` folder next to this file.
#   Each numbered .ps1 in there is loaded in alphanumeric order:
#       00-core.ps1        <- foundation (helpers, encoding, version checks)
#       10-psreadline.ps1  <- command-line behavior (history, colors, keys)
#       20-prompt.ps1      <- the prompt itself (oh-my-posh)
#       30-aliases.ps1     <- friendlier shortcuts for common commands
#       40-fs.ps1          <- file and folder utilities
#       50-system.ps1      <- system info, processes, profile management
#       60-git.ps1         <- git shortcuts
#       70-net.ps1         <- network tools
#       80-clipboard.ps1   <- clipboard helpers
#       90-deferred.ps1    <- slow extras, loaded after the first prompt
#       99-help.ps1        <- the `Show-Help` reference command
#
# ADD YOUR OWN
#   Drop a new file in `profile\` named for example `85-mine.ps1`.
#   The number controls load order. It will be picked up automatically.
#
# HANDY TOGGLES
#   $env:PROFILE_VERBOSE=1   - print how long the profile took to load
#   $ProfileLoadErrors       - inspect any module that failed to load
# =============================================================================

# Idempotency guard. PowerShell loads AllUsersAllHosts then CurrentUserAllHosts;
# both stubs (machine + user) dot-source this file, so without this we'd load
# every module twice, queue every deferred action twice, etc.
if ($Global:__UltimateProfileLoaded) { return }
$Global:__UltimateProfileLoaded = $true

$ProfileStart = [System.Diagnostics.Stopwatch]::StartNew()

# Locate the profile root (the directory containing this file).
# When invoked via dot-source from a stub, $PSCommandPath points here.
$PROFILE_ROOT = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
                else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$env:PROFILE_ROOT = $PROFILE_ROOT

# Track failures without aborting profile load.
$Global:ProfileLoadErrors = @()

$moduleDir = Join-Path $PROFILE_ROOT 'profile'
if (Test-Path $moduleDir) {
    Get-ChildItem -Path $moduleDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object {
            try { . $_.FullName }
            catch {
                $Global:ProfileLoadErrors += [pscustomobject]@{
                    Module  = $_.Name
                    Message = $_.Exception.Message
                }
            }
        }
}

if ($Global:ProfileLoadErrors.Count -gt 0) {
    Write-Host "Profile loaded with $($Global:ProfileLoadErrors.Count) module error(s). Inspect `$ProfileLoadErrors." -ForegroundColor Yellow
}

$ProfileStart.Stop()
if ($env:PROFILE_VERBOSE) {
    Write-Host ("Profile loaded in {0:N0}ms" -f $ProfileStart.Elapsed.TotalMilliseconds) -ForegroundColor DarkGray
}
Remove-Variable ProfileStart, moduleDir -ErrorAction SilentlyContinue
