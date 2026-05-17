# =============================================================================
# 20-prompt.ps1 - The prompt at the start of every line
#
# WHAT THIS DOES
#   Sets up your prompt - the bit that shows your folder, git branch, and
#   whether the last command succeeded. Tries the following in order:
#     1. starship      with themes\starship.toml         (Dracula, preferred)
#     2. oh-my-posh    with themes\ultimate.omp.json     (fallback)
#     3. A simple built-in prompt                        (always works)
#
#   Also initializes zoxide so `z folder-fragment` jumps to recent folders.
#
#   Override the engine choice via $env:PROMPT_ENGINE = 'starship' | 'posh' | 'none'.
#   Point starship at a different config via $env:STARSHIP_CONFIG.
#   Point oh-my-posh at a different theme via $env:POSH_THEME.
# =============================================================================

# Engine selection order (override with $env:PROMPT_ENGINE = 'starship' | 'posh' | 'none'):
#   1. starship  (Dracula-themed config from themes/starship.toml)
#   2. oh-my-posh (themes/ultimate.omp.json)
#   3. built-in fallback
function Resolve-PoshTheme {
    if ($env:POSH_THEME -and (Test-Path $env:POSH_THEME)) { return $env:POSH_THEME }
    $candidates = @(
        (Join-Path $env:PROFILE_ROOT 'themes\ultimate.omp.json'),
        (Join-Path $HOME 'Documents\PowerShell\cobalt2.omp.json')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

$engine = if ($env:PROMPT_ENGINE) { $env:PROMPT_ENGINE.ToLower() } else { 'auto' }

# Try starship first when in auto mode, or when explicitly requested.
$starshipDone = $false
if (($engine -in 'auto','starship') -and (Test-Command 'starship')) {
    # Point starship at the shipped Dracula config if STARSHIP_CONFIG isn't already set.
    $shippedToml = Join-Path $env:PROFILE_ROOT 'themes\starship.toml'
    if ((Test-Path $shippedToml) -and (-not $env:STARSHIP_CONFIG)) {
        $env:STARSHIP_CONFIG = $shippedToml
    }
    try {
        Invoke-Expression (& starship init powershell)
        $starshipDone = $true
    } catch {
        Write-Warning "starship init failed: $_"
    }
}

# Fall back to oh-my-posh.
if ((-not $starshipDone) -and ($engine -in 'auto','posh') -and (Test-Command 'oh-my-posh')) {
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
elseif ((-not $starshipDone) -and ($engine -eq 'none')) {
    # Explicit user request: leave the built-in prompt alone.
}
elseif (-not $starshipDone) {
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
Remove-Variable engine, starshipDone, shippedToml -ErrorAction SilentlyContinue
