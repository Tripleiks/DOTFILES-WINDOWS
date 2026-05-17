# =============================================================================
# 30-aliases.ps1 - Friendlier shortcuts for common commands
#
# WHAT THIS DOES
#   Replaces stock PowerShell commands with nicer modern versions, but ONLY
#   if the modern tool is actually installed. If you don't have the tool,
#   nothing changes - the built-in still works.
#
#   Examples once you have the tools installed:
#     ls       -> colorful eza listing with file icons
#     cat f    -> bat (syntax-highlighted preview)
#     grep ... -> ripgrep (much faster than Select-String)
#     find ... -> fd (faster + simpler than `find`)
#     ..       -> go up one folder   (... two folders, .... three)
#     edit f   -> open in nvim / VS Code / notepad (whichever you have)
#     unzip f  -> Expand-Archive
#     open f   -> open with the default app
# =============================================================================

# `grep` -> ripgrep (rg) preferred; otherwise Select-String.
if (Test-Command 'rg') {
    Remove-Item Alias:grep -Force -ErrorAction SilentlyContinue
    function Global:grep { rg @args }
} else {
    Set-Alias -Name grep -Value Select-String -Scope Global -Option AllScope -Force
}

# `cat` -> bat with sensible defaults. Keep `gc` (Get-Content) for raw use.
if (Test-Command 'bat') {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    $env:BAT_THEME = if ($env:BAT_THEME) { $env:BAT_THEME } else { 'OneHalfDark' }
    function Global:cat { bat --paging=never --style=plain @args }
    function Global:less { bat --paging=always @args }
}

# `ls` / `ll` / `la` / `lt` -> eza if available; otherwise Format-Table.
if (Test-Command 'eza') {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function Global:ls { eza --group-directories-first --icons=auto --color=auto @args }
    function Global:ll { eza -l --group-directories-first --icons=auto --git --color=auto @args }
    function Global:la { eza -la --group-directories-first --icons=auto --git --color=auto @args }
    function Global:lt { eza --tree --level=2 --group-directories-first --icons=auto @args }
    function Global:lta { eza --tree --level=4 -a --group-directories-first --icons=auto @args }
} else {
    function Global:ll { Get-ChildItem -Force @args | Format-Table -AutoSize }
    function Global:la { Get-ChildItem @args | Format-Table -AutoSize }
    function Global:lt {
        param([string]$Path = '.', [int]$Depth = 2)
        Get-ChildItem -Path $Path -Recurse -Depth $Depth -Force |
            ForEach-Object { '  ' * ($_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count - $Path.Split([IO.Path]::DirectorySeparatorChar).Count) + $_.Name }
    }
}

# `find` -> fd if available.
if (Test-Command 'fd') {
    function Global:find { fd @args }
}

# Editor — prefer nvim, then code, then notepad.
$Global:EDITOR = if ($env:EDITOR) { $env:EDITOR }
                 elseif (Test-Command 'nvim') { 'nvim' }
                 elseif (Test-Command 'code')  { 'code' }
                 else { 'notepad' }
$env:EDITOR = $Global:EDITOR
function Global:edit { & $Global:EDITOR @args }

# Misc useful aliases.
Set-Alias -Name unzip -Value Expand-Archive -Scope Global -Option AllScope -Force
Set-Alias -Name open  -Value Invoke-Item    -Scope Global -Option AllScope -Force

# `..`, `...`, `....` quick parent-directory jumps.
function Global:.. { Set-Location .. }
function Global:... { Set-Location ../.. }
function Global:.... { Set-Location ../../.. }

# `~` -> home.
function Global:~ { Set-Location $HOME }

# `cls` already exists; add `clear` to be safe.
if (-not (Get-Command clear -ErrorAction SilentlyContinue)) {
    Set-Alias -Name clear -Value Clear-Host -Scope Global -Force
}
