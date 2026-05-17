# =============================================================================
# 40-fs.ps1 - File and folder utilities
#
# WHAT THIS GIVES YOU
#   Familiar Unix-style file commands on Windows:
#     touch <file>          -> create empty file (or update its modified time)
#     mkcd <dir>            -> make folder + cd into it
#     trash <path>          -> move to Recycle Bin (recoverable!)
#     ff <name>             -> find files by name (uses fd if installed)
#     head / tail <file>    -> first / last 10 lines (-Follow tails live)
#     sed <file> a b        -> replace text in a file in-place
#     which <cmd>           -> where does this command live?
#     du / df               -> folder sizes / drive free space
#     tree [path] [depth]   -> directory tree
#     extract <archive>     -> unzip anything (zip / tar.gz / 7z / ...)
# =============================================================================

function Global:touch {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Paths)
    foreach ($p in $Paths) {
        if (Test-Path $p) {
            (Get-Item $p).LastWriteTime = Get-Date
        } else {
            New-Item -Path $p -ItemType File -Force | Out-Null
        }
    }
}

function Global:mkcd {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null }
    Set-Location -Path $Path
}

# Send to recycle bin instead of permanent delete.
function Global:trash {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments)][string[]]$Path)
    process {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
        foreach ($p in $Path) {
            if (-not (Test-Path $p)) { Write-Warning "trash: $p not found"; continue }
            $full = (Resolve-Path $p).Path
            if (Test-Path $full -PathType Container) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                    $full, 'OnlyErrorDialogs', 'SendToRecycleBin')
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $full, 'OnlyErrorDialogs', 'SendToRecycleBin')
            }
        }
    }
}

# Quick file find by name (uses fd when available, else Get-ChildItem -Recurse).
function Global:ff {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    if (Test-Command 'fd') {
        fd --type f $Name
    } else {
        Get-ChildItem -Recurse -Filter $Name -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }
}

function Global:head {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [int]$Lines = 10)
    Get-Content -Path $Path -TotalCount $Lines
}

function Global:tail {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [int]$Lines = 10, [switch]$Follow)
    if ($Follow) { Get-Content -Path $Path -Tail $Lines -Wait }
    else         { Get-Content -Path $Path -Tail $Lines }
}

# In-place text replace (Unix `sed -i` analogue).
function Global:sed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Find,
        [Parameter(Mandatory)][string]$Replace
    )
    if (-not (Test-Path $File)) { Write-Error "sed: $File not found"; return }
    (Get-Content -Raw $File) -replace $Find, $Replace | Set-Content -Path $File -NoNewline
}

# Show full path of a command (Unix `which`).
function Global:which {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return }
    switch ($cmd.CommandType) {
        'Application' { $cmd.Source }
        'Alias'       { "alias $($cmd.Name) -> $($cmd.Definition)" }
        'Function'    { "function $($cmd.Name)" }
        'Cmdlet'      { "cmdlet $($cmd.ModuleName)\$($cmd.Name)" }
        default       { $cmd | Format-List | Out-String }
    }
}

# Disk usage — folder size in human-readable form.
function Global:du {
    [CmdletBinding()]
    param([string]$Path = '.', [switch]$Summary)
    $items = if ($Summary) {
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem -Path $Path -Force -Directory -ErrorAction SilentlyContinue
    }
    foreach ($i in $items) {
        $size = (Get-ChildItem -Path $i.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        [pscustomobject]@{
            Size = if ($size) { Format-FileSize $size } else { '0 B' }
            Name = $i.Name
        }
    }
}

# Disk free — top-level overview of all filesystem drives.
function Global:df {
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        [pscustomobject]@{
            Drive = $_.Name
            Used  = if ($_.Used) { Format-FileSize $_.Used } else { '—' }
            Free  = if ($_.Free) { Format-FileSize $_.Free } else { '—' }
            Total = if ($_.Used -and $_.Free) { Format-FileSize ($_.Used + $_.Free) } else { '—' }
            Root  = $_.Root
        }
    }
}

# Helper: format bytes to KiB/MiB/GiB/TiB.
function Global:Format-FileSize {
    param([Parameter(Mandatory)][double]$Bytes)
    $u = 'B','KiB','MiB','GiB','TiB','PiB'
    $i = 0
    while ($Bytes -ge 1024 -and $i -lt $u.Count - 1) { $Bytes /= 1024; $i++ }
    '{0:N2} {1}' -f $Bytes, $u[$i]
}

# Tree view fallback for systems without eza.
function Global:tree {
    param([string]$Path = '.', [int]$Depth = 3)
    if (Test-Command 'eza') {
        eza --tree --level=$Depth --icons=auto $Path
    } elseif (Test-Command 'tree.com') {
        tree.com $Path /F
    } else {
        Get-ChildItem -Path $Path -Recurse -Depth $Depth -Force |
            ForEach-Object {
                $rel = $_.FullName.Substring((Resolve-Path $Path).Path.Length)
                $indent = ($rel -split '[\\/]').Count - 1
                '{0}{1}' -f ('  ' * $indent), $_.Name
            }
    }
}

# Extract any archive by extension (zip, 7z, tar.gz, tar.xz, tar, gz).
function Global:extract {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [string]$Destination = '.')
    if (-not (Test-Path $Path)) { Write-Error "extract: $Path not found"; return }
    $ext = [IO.Path]::GetExtension($Path).ToLower()
    switch -Regex ($Path.ToLower()) {
        '\.zip$'              { Expand-Archive -Path $Path -DestinationPath $Destination -Force; return }
        '\.tar\.gz$|\.tgz$'   { if (Test-Command 'tar') { tar -xzf $Path -C $Destination } else { Write-Error 'extract: tar not available' }; return }
        '\.tar\.xz$|\.txz$'   { if (Test-Command 'tar') { tar -xJf $Path -C $Destination } else { Write-Error 'extract: tar not available' }; return }
        '\.tar$'              { if (Test-Command 'tar') { tar -xf $Path -C $Destination } else { Write-Error 'extract: tar not available' }; return }
        '\.gz$'               { if (Test-Command 'tar') { tar -xzf $Path -C $Destination } else { Write-Error 'extract: tar not available' }; return }
        '\.7z$|\.rar$'        { if (Test-Command '7z') { 7z x $Path "-o$Destination" } else { Write-Error 'extract: 7z not available — winget install 7zip.7zip' }; return }
        default               { Write-Error "extract: unsupported archive type: $ext" }
    }
}
