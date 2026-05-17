# =============================================================================
# 80-clipboard.ps1 - Clipboard helpers
#
# WHAT THIS GIVES YOU
#     <command> | cb     -> send the output of a command to the clipboard
#     paste              -> paste clipboard contents to stdout
#     cbf <file>         -> copy a whole file's contents to the clipboard
#
#   Example:
#     Get-ChildItem | cb           # current folder listing now on clipboard
#     paste | Select-String error  # search clipboard for "error"
# =============================================================================

# Copy stdin to clipboard. Usage:  Get-Content file.txt | cb
function Global:cb {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject)
    begin { $buf = New-Object System.Collections.Generic.List[string] }
    process {
        if ($null -ne $InputObject) {
            $buf.Add(($InputObject | Out-String).TrimEnd("`r","`n"))
        }
    }
    end { ($buf -join "`n") | Set-Clipboard }
}

# Paste clipboard contents to stdout. Usage:  paste | grep foo
function Global:paste { Get-Clipboard }

# Copy a file's contents to clipboard.
function Global:Copy-FileToClipboard {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -Raw -Path $Path | Set-Clipboard
}
Set-Alias -Name cbf -Value Copy-FileToClipboard -Scope Global -Force
