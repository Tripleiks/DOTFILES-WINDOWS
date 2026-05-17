# =============================================================================
# 10-psreadline.ps1 - Smarter command line (history, colors, keys)
#
# WHAT THIS DOES
#   Configures PSReadLine, the module that controls your typing experience.
#   Once loaded:
#     - Up/Down arrow searches history filtered to what you have already typed
#     - Tab opens a menu of completions instead of cycling one at a time
#     - Tokens are color-coded (commands blue, strings peach, etc.)
#     - Past commands appear ghosted as you type (autosuggestions)
#     - F7 pops up a clickable history grid; Ctrl+W deletes the previous word
#     - Quotes / brackets auto-wrap text you have selected
#
#   Gracefully falls back on older PSReadLine versions that don't support
#   newer features like list-view prediction.
# =============================================================================

if (-not (Get-Module -ListAvailable PSReadLine)) { return }

Import-Module PSReadLine -ErrorAction SilentlyContinue
$psrlVersion = (Get-Module PSReadLine).Version

# ListView prediction needs PSReadLine 2.2+. Fall back to InlineView otherwise.
$predictionView = if ($psrlVersion -ge [version]'2.2.0') { 'ListView' } else { 'InlineView' }

$psrlOptions = @{
    EditMode              = 'Windows'
    BellStyle             = 'None'
    HistoryNoDuplicates   = $true
    HistorySearchCursorMovesToEnd = $true
    MaximumHistoryCount   = 8192
    PredictionSource      = 'HistoryAndPlugin'
    PredictionViewStyle   = $predictionView
    ShowToolTips          = $true
    Colors                = @{
        Command            = '#87CEEB'
        Parameter          = '#98FB98'
        Operator           = '#FFB6C1'
        Variable           = '#DDA0DD'
        String             = '#FFDAB9'
        Number             = '#B0E0E6'
        Type               = '#F0E68C'
        Comment            = '#7F848E'
        Keyword            = '#C678DD'
        Error              = '#FF6347'
        Selection          = '#FFFFFF'
        InlinePrediction   = '#7F848E'
        ListPrediction     = '#87CEEB'
    }
}
# Drop options & color keys not supported on older PSReadLine versions.
if ($psrlVersion -lt [version]'2.2.0') {
    $psrlOptions.Remove('PredictionViewStyle') | Out-Null
    $psrlOptions.Colors.Remove('ListPrediction') | Out-Null
    if ($psrlVersion -lt [version]'2.1.0') {
        $psrlOptions.Remove('PredictionSource')      | Out-Null
        $psrlOptions.Colors.Remove('InlinePrediction') | Out-Null
    }
}
# Predictions need a real TTY with VT processing. If the host is redirected
# (e.g. scripted profile load) the option throws — fall back to a quieter config.
try {
    Set-PSReadLineOption @psrlOptions
} catch {
    $psrlOptions.Remove('PredictionSource')    | Out-Null
    $psrlOptions.Remove('PredictionViewStyle') | Out-Null
    try { Set-PSReadLineOption @psrlOptions } catch { Write-Warning "PSReadLine setup partial: $($_.Exception.Message)" }
}

# --- Keybinds ----------------------------------------------------------------
# Smart arrows: search history filtered by current input.
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Tab cycles a menu of completions instead of inline cycling.
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete

# Word movement & deletion (readline / bash parity).
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+w'          -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d'           -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+d'          -Function DeleteChar

# Undo / redo.
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Accept the next word of the prediction (like fish ctrl+right).
Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ForwardWord -ErrorAction SilentlyContinue

# F7 — pop up a history grid (legacy convenience, PS 5.1-style).
Set-PSReadLineKeyHandler -Key F7 -BriefDescription 'History' -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern) { $pattern = [regex]::Escape($pattern) }
    $history = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() |
        Where-Object { -not $pattern -or $_.CommandLine -match $pattern } |
        Select-Object -ExpandProperty CommandLine -Unique |
        Out-GridView -Title 'History' -PassThru
    if ($history) {
        [Microsoft.PowerShell.PSConsoleReadLine]::DeleteLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($history -join "`n"))
    }
}

# Auto-wrap selection in matching quotes/brackets.
Set-PSReadLineKeyHandler -Key '"',"'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription 'Insert paired quote, or wrap selection' `
    -ScriptBlock {
        param($key, $arg)
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $selStart = $null; $selLen = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selStart, [ref]$selLen)
        if ($selStart -ne -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selStart, $selLen, "$($key.KeyChar)" + $line.Substring($selStart, $selLen) + "$($key.KeyChar)")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selStart + $selLen + 2)
            return
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$($key.KeyChar)")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }

Remove-Variable psrlVersion, psrlOptions, predictionView -ErrorAction SilentlyContinue
