# =============================================================================
# 50-system.ps1 - System info, processes, and profile management
#
# WHAT THIS GIVES YOU
#     uptime / sysinfo            -> "how long since reboot" / system summary
#     pgrep / pkill / k9 <name>   -> find / interactive-stop / force-stop
#                                    processes by name (regex)
#     sudo <command>              -> run as admin (uses gsudo if installed)
#     env [filter]                -> list environment variables
#     path                        -> show $PATH as a numbered list
#     ep / epd / reload           -> edit profile / open profile folder / reload
#     Update-Profile              -> git pull the dotfiles repo and reload
#     docs / dl / dot / ghub      -> quick folder jumps
#     sha256 / md5 <file>         -> file hash
# =============================================================================

function Global:uptime {
    $boot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $span = (Get-Date) - $boot
    [pscustomobject]@{
        Booted  = $boot
        Days    = $span.Days
        Hours   = $span.Hours
        Minutes = $span.Minutes
        Seconds = $span.Seconds
        Total   = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes
    }
}

function Global:sysinfo {
    $os    = Get-CimInstance Win32_OperatingSystem
    $cs    = Get-CimInstance Win32_ComputerSystem
    $cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
    $boot  = $os.LastBootUpTime
    $uptm  = ((Get-Date) - $boot)
    [pscustomobject][ordered]@{
        Host       = $cs.Name
        User       = $env:USERNAME
        OS         = "$($os.Caption) $($os.Version)"
        Kernel     = $os.BuildNumber
        Uptime     = '{0}d {1}h {2}m' -f $uptm.Days, $uptm.Hours, $uptm.Minutes
        CPU        = $cpu.Name.Trim()
        Cores      = "$($cpu.NumberOfCores)c / $($cpu.NumberOfLogicalProcessors)t"
        MemoryGB   = '{0:N1} / {1:N1}' -f (($os.FreePhysicalMemory * 1KB) / 1GB), ($cs.TotalPhysicalMemory / 1GB)
        Shell      = "PowerShell $($PSVersionTable.PSVersion)"
        Terminal   = if ($env:WT_SESSION) { 'Windows Terminal' }
                     elseif ($env:TERM_PROGRAM) { $env:TERM_PROGRAM }
                     else { 'Console Host' }
    }
}

# `pgrep`/`pkill`/`k9` — Unix process tools (name pattern, regex).
function Global:pgrep {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern)
    Get-Process | Where-Object { $_.ProcessName -match $Pattern } |
        Select-Object Id, ProcessName, @{n='MemMB';e={[int]($_.WorkingSet64/1MB)}}, CPU, Path
}

function Global:pkill {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern, [switch]$Force)
    Get-Process | Where-Object { $_.ProcessName -match $Pattern } |
        ForEach-Object {
            if ($PSCmdlet.ShouldContinue("Kill PID $($_.Id) ($($_.ProcessName))?", 'pkill') -or $Force) {
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        }
}

function Global:k9 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern)
    Get-Process | Where-Object { $_.ProcessName -match $Pattern } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# `top` — interactive system monitor. Uses `bottom` (btm) if installed,
# otherwise falls back to a one-shot snapshot of the top 20 CPU consumers.
function Global:top {
    if (Test-Command 'btm') { btm @args; return }
    Get-Process | Sort-Object -Property CPU -Descending |
        Select-Object -First 20 Id, ProcessName,
            @{n='CPU';e={[math]::Round([double]($_.CPU),1)}},
            @{n='MemMB';e={[int]($_.WorkingSet64/1MB)}}
}

# Profile management.
function Global:Edit-Profile { & $Global:EDITOR (Join-Path $env:PROFILE_ROOT 'Microsoft.PowerShell_profile.ps1') }
Set-Alias -Name ep -Value Edit-Profile -Scope Global -Force

function Global:Open-ProfileDir { & $Global:EDITOR $env:PROFILE_ROOT }
Set-Alias -Name epd -Value Open-ProfileDir -Scope Global -Force

function Global:Reload-Profile {
    $entry = Join-Path $env:PROFILE_ROOT 'Microsoft.PowerShell_profile.ps1'
    if (-not (Test-Path $entry)) { Write-Error "Profile not found at $entry"; return }
    . $entry
    Write-Host 'Profile reloaded.' -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile -Scope Global -Force

# Manual profile update from the dotfiles repo (no auto-update on load).
function Global:Update-Profile {
    [CmdletBinding()]
    param()
    $root = $Global:DOTFILES_ROOT
    if (-not (Test-Path (Join-Path $root '.git'))) {
        Write-Warning "DOTFILES_ROOT ($root) is not a git repo. Pull manually."
        return
    }
    Push-Location $root
    try {
        git pull --ff-only
        Write-Host 'Reloading profile...' -ForegroundColor Cyan
        Reload-Profile
    } finally { Pop-Location }
}

# Elevation. Prefer gsudo if installed (full UAC interop); otherwise relaunch.
function Global:sudo {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)
    if (Test-Command 'gsudo') { gsudo @Command; return }
    if ($Command.Count -eq 0) {
        Start-Process -Verb RunAs -FilePath (Get-Process -Id $PID).Path
    } else {
        $joined = $Command -join ' '
        Start-Process -Verb RunAs -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoExit', '-Command', $joined)
    }
}

# `env` — list environment variables, optionally filtered.
function Global:env {
    [CmdletBinding()]
    param([string]$Filter = '*')
    Get-ChildItem Env: | Where-Object Name -Like $Filter | Sort-Object Name |
        Select-Object Name, Value
}

# `path` — show $env:PATH as a numbered list.
function Global:path {
    $i = 0
    $env:PATH -split [IO.Path]::PathSeparator | ForEach-Object {
        [pscustomobject]@{ '#' = $i++; Path = $_; Exists = (Test-Path $_) }
    }
}

# Quick documents jump.
function Global:docs { Set-Location ([Environment]::GetFolderPath('MyDocuments')) }
function Global:dl   { Set-Location (Join-Path $HOME 'Downloads') }
function Global:dot  { Set-Location $Global:DOTFILES_ROOT }
# Note: no `gh` jump function — it would shadow the GitHub CLI. Use `ghub` (in 60-git.ps1).

# Hash helpers.
function Global:sha256 { param([Parameter(Mandatory)][string]$Path) (Get-FileHash -Path $Path -Algorithm SHA256).Hash }
function Global:md5    { param([Parameter(Mandatory)][string]$Path) (Get-FileHash -Path $Path -Algorithm MD5).Hash }
