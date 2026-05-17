# =============================================================================
# 45-yazi.ps1 - Yazi file manager shell integration
#
# WHAT THIS DOES
#   1. Points Yazi at a Unix `file.exe` for MIME detection. Yazi uses
#      `file -bL --mime-type <path>` to figure out what previewer to run; on
#      Windows that binary isn't shipped, so without this nothing previews.
#      Git for Windows bundles a usable `file.exe` under usr\bin\ - we set
#      $env:YAZI_FILE_ONE to it if we can find one.
#   2. Defines `y` - runs Yazi and, after you quit, cd's into whatever folder
#      you were browsing. The plain `yazi` command still works the same way;
#      `y` is the wrapper that follows the highlighted directory on exit.
#
#   Loaded only when yazi is on PATH, so machines without yazi installed
#   are unaffected.
# =============================================================================

if (Test-Command 'yazi') {

    # --- 1. Wire up file.exe for MIME detection -------------------------------
    # Only set YAZI_FILE_ONE if the user hasn't already, and only to a path
    # that actually exists. Re-checked each profile load so a Git install /
    # uninstall between sessions is reflected.
    if (-not $env:YAZI_FILE_ONE) {
        $fileExe = $null
        # 1a) Anything on PATH wins (e.g. WSL exposing /usr/bin/file).
        $onPath = Get-Command file.exe -ErrorAction SilentlyContinue
        if ($onPath) { $fileExe = $onPath.Source }
        # 1b) Common Git for Windows install locations.
        if (-not $fileExe) {
            foreach ($p in @(
                'C:\Program Files\Git\usr\bin\file.exe',
                'C:\Program Files (x86)\Git\usr\bin\file.exe',
                "$env:LOCALAPPDATA\Programs\Git\usr\bin\file.exe",
                "$env:USERPROFILE\scoop\apps\git\current\usr\bin\file.exe"
            )) {
                if (Test-Path $p) { $fileExe = $p; break }
            }
        }
        if ($fileExe) { $env:YAZI_FILE_ONE = $fileExe }
    }

    # --- 2. Make chafa.exe reachable by yazi's child processes ----------------
    # The chafa-preview plugin (Yazi/plugins/chafa-preview.yazi/main.lua) shells
    # out to `chafa` for image rendering. Winget's chafa install only puts a
    # zero-length SymbolicLink shim in %LOCALAPPDATA%\Microsoft\WinGet\Links\;
    # CreateProcessW (which yazi's Rust spawn uses) does not follow that kind
    # of shim, so yazi reports "program not found" even though the shim is on
    # PATH. Workaround: find the real Chafa.exe under the winget package dir
    # and prepend its directory to PATH, so subsequent PATH lookups resolve to
    # a real exe.
    if (-not (Get-Command chafa.exe -ErrorAction SilentlyContinue) -or
        ((Get-Command chafa.exe -ErrorAction SilentlyContinue).Source -like '*\WinGet\Links\*')) {
        $chafaPkg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter 'hpjansson.Chafa_*' -Directory -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($chafaPkg) {
            $chafaExe = Get-ChildItem $chafaPkg.FullName -Filter 'Chafa.exe' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 0 } | Select-Object -First 1
            if ($chafaExe) {
                $chafaDir = $chafaExe.DirectoryName
                if ($env:Path -notlike "*$chafaDir*") {
                    $env:Path = "$chafaDir;$env:Path"
                }
            }
        }
    }

    # --- 3. The `y` wrapper ---------------------------------------------------
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
