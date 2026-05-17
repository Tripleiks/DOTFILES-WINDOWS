# =============================================================================
# 45-yazi.ps1 - Yazi file manager shell integration
#
# WHAT THIS DOES
#   Defines `y` - runs Yazi and, after you quit, cd's into whatever folder
#   you were browsing. The plain `yazi` command still works the same way;
#   `y` is the wrapper that follows the highlighted directory on exit.
#
#   Loaded only when yazi is on PATH, so machines without yazi installed
#   are unaffected.
# =============================================================================

if (Test-Command 'yazi') {
    function Global:y {
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            yazi @args --cwd-file=$tmp
            $cwd = Get-Content -LiteralPath $tmp -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($cwd -and $cwd -ne $PWD.Path) {
                Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
            }
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}
