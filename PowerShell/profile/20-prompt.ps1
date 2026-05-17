# =============================================================================
# 20-prompt.ps1 - The prompt at the start of every line
#
# WHAT THIS DOES
#   Sets up your prompt - the bit that shows your folder, git branch, and
#   whether the last command succeeded. Tries the following in order:
#     1. oh-my-posh with the ultimate.omp.json theme  (preferred)
#     2. starship, if oh-my-posh isn't installed
#     3. A simple built-in fallback that always works
#
#   Also initializes zoxide so `z folder-fragment` jumps to recent folders.
#
#   Tip: set $env:POSH_THEME to a different .omp.json path to use your own
#   theme instead of the one shipped in themes/.
# =============================================================================

# Look for the theme: $env:POSH_THEME (user override), then themes/ultimate.omp.json,
# then any cobalt2.omp.json kept in $HOME\Documents\PowerShell for CTT-compat.
function Resolve-PoshTheme {
    if ($env:POSH_THEME -and (Test-Path $env:POSH_THEME)) { return $env:POSH_THEME }
    $candidates = @(
        (Join-Path $env:PROFILE_ROOT 'themes\ultimate.omp.json'),
        (Join-Path $HOME 'Documents\PowerShell\cobalt2.omp.json')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

if (Test-Command 'oh-my-posh') {
    $theme = Resolve-PoshTheme
    try {
        if ($theme) {
            oh-my-posh init pwsh --config $theme | Invoke-Expression
        } else {
            oh-my-posh init pwsh | Invoke-Expression
        }
    } catch {
        Write-Warning "oh-my-posh init failed: $_"
    }
    Remove-Variable theme -ErrorAction SilentlyContinue
}
elseif (Test-Command 'starship') {
    # Honor an existing Starship install if oh-my-posh isn't there yet.
    try { Invoke-Expression (&starship init powershell) }
    catch { Write-Warning "starship init failed: $_" }
}
else {
    # Fallback prompt — minimal but informative when no third-party prompt exists.
    function Global:prompt {
        $lastOk    = $?
        $exitCode  = $LASTEXITCODE
        $location  = (Get-Location).Path.Replace($HOME, '~')
        $userHost  = "$env:USERNAME@$env:COMPUTERNAME"
        $branch    = $null
        try {
            $branch = (git -C (Get-Location) rev-parse --abbrev-ref HEAD 2>$null)
        } catch {}
        $statusSym = if (-not $lastOk -or ($exitCode -and $exitCode -ne 0)) { '✗' } else { '❯' }
        $statusCol = if (-not $lastOk -or ($exitCode -and $exitCode -ne 0)) { "`e[31m" } else { "`e[32m" }
        $reset = "`e[0m"

        $line  = "`e[90m$userHost$reset "
        $line += "`e[36m$location$reset"
        if ($branch) { $line += " `e[33m($branch)$reset" }
        $line += "`n$statusCol$statusSym$reset "
        $line
    }
}

# zoxide — smart `z` / `zi` for jumping directories. Init eagerly (it's fast).
if (Test-Command 'zoxide') {
    try {
        zoxide init --cmd z powershell | Out-String | Invoke-Expression
    } catch {
        Write-Warning "zoxide init failed: $_"
    }
}

Remove-Item function:Resolve-PoshTheme -ErrorAction SilentlyContinue
