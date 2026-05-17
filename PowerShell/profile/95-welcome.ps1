# =============================================================================
# 95-welcome.ps1 - fastfetch + colorful welcome box on shell start
#
# WHAT YOU GET
#   When a new PowerShell window opens, this prints (in order):
#     1. fastfetch    - ASCII system summary (logo + OS / CPU / mem / etc.)
#     2. Welcome box  - Dracula-themed box with:
#                         - time-based greeting (Guten Morgen / Tag / Abend / Nacht)
#                         - date and time in German
#                         - current weather + 15h trend (from wttr.in, cached 5 min)
#                         - shell / OS / hostname
#                         - daily tip
#
#   You can also call `Show-Welcome` any time to redisplay it.
#
# DISABLE / TWEAK via environment variables (set BEFORE starting pwsh):
#     $env:WELCOME_NO_FASTFETCH = 1   # skip fastfetch
#     $env:WELCOME_NO_BOX       = 1   # skip the welcome box
#     $env:WELCOME_NO_WEATHER   = 1   # box still renders, just no weather lines
#     $env:WELCOME_CITY         = 'Berlin'
#     $env:WELCOME_LANG         = 'en'      # 'de' (default) or 'en'
#     $env:WELCOME_WIDTH        = 80        # inner width of the box (default 72)
#
# Ported from welcome.zsh in the macOS DOTFILES repo (same look + tips list).
# =============================================================================

# --- Configuration -----------------------------------------------------------
$script:WB_CITY     = if ($env:WELCOME_CITY)  { $env:WELCOME_CITY }  else { 'Hamburg' }
$script:WB_LANG     = if ($env:WELCOME_LANG)  { $env:WELCOME_LANG }  else { 'de' }
$script:WB_WIDTH    = if ($env:WELCOME_WIDTH) { [int]$env:WELCOME_WIDTH } else { 72 }
$script:WB_CACHE_TTL = 300
$script:WB_CACHE_DIR = Join-Path $env:LOCALAPPDATA 'welcome-box'
if (-not (Test-Path $script:WB_CACHE_DIR)) {
    try { New-Item -ItemType Directory -Path $script:WB_CACHE_DIR -Force | Out-Null } catch {}
}

# Dracula palette pre-rendered as 24-bit ANSI strings (cheap lookup).
$ESC = [char]27
$script:WB_C = @{
    cyan    = "$ESC[38;2;139;233;253m"
    green   = "$ESC[38;2;80;250;123m"
    orange  = "$ESC[38;2;255;184;108m"
    pink    = "$ESC[38;2;255;121;198m"
    purple  = "$ESC[38;2;189;147;249m"
    red     = "$ESC[38;2;255;85;85m"
    yellow  = "$ESC[38;2;241;250;140m"
    comment = "$ESC[38;2;98;114;164m"
    fg      = "$ESC[38;2;248;248;242m"
    bold    = "$ESC[1m"
    dim     = "$ESC[2m"
    reset   = "$ESC[0m"
}

# --- Visible-width helper ----------------------------------------------------
# Strips ANSI sequences, counts graphemes, returns 2 for likely-double-wide chars
# (emoji, CJK, East-Asian wide) so the box edges line up in Windows Terminal.
function Get-WelcomeStrLen {
    param([string]$Text)
    if (-not $Text) { return 0 }
    $clean = $Text -replace "$ESC\[[0-9;?]*[a-zA-Z]", '' `
                   -replace "$ESC\][^`a$ESC]*[`a$ESC\\]", ''
    $width = 0
    $enum = [System.Globalization.StringInfo]::GetTextElementEnumerator($clean)
    while ($enum.MoveNext()) {
        $elem = [string]$enum.Current
        $cp = [char]::ConvertToUtf32($elem, 0)
        $isWide =
            ($cp -ge 0x1F000 -and $cp -le 0x1FFFF) -or
            ($cp -ge 0x2600  -and $cp -le 0x27BF)  -or
            ($cp -in 0x231A,0x231B,0x2328,0x23F0,0x23F1,0x23F2,0x23F3) -or
            ($cp -ge 0x1100  -and $cp -le 0x115F)  -or
            ($cp -ge 0x2E80  -and $cp -le 0x303E)  -or
            ($cp -ge 0x3041  -and $cp -le 0x33FF)  -or
            ($cp -ge 0x3400  -and $cp -le 0x4DBF)  -or
            ($cp -ge 0x4E00  -and $cp -le 0x9FFF)  -or
            ($cp -ge 0xAC00  -and $cp -le 0xD7A3)
        if ($isWide) { $width += 2 } else { $width += 1 }
    }
    $width
}

# --- Rendering helpers -------------------------------------------------------
function _wb_line {
    param([string]$Content, [string]$BorderColor = 'cyan')
    $vis = Get-WelcomeStrLen $Content
    $pad = $script:WB_WIDTH - $vis
    if ($pad -lt 0) { $pad = 0 }
    $bc = $script:WB_C[$BorderColor]
    $r  = $script:WB_C.reset
    "${bc}║${r} ${Content}$(' ' * $pad)${bc}║${r}"
}

function _wb_sep {
    param([string]$BorderColor = 'pink')
    $bc = $script:WB_C[$BorderColor]
    $r  = $script:WB_C.reset
    "${bc}╠$('═' * ($script:WB_WIDTH + 1))╣${r}"
}

function _wb_border {
    param([string]$Kind = 'top')
    $left  = if ($Kind -eq 'top') { '╔' } else { '╚' }
    $right = if ($Kind -eq 'top') { '╗' } else { '╝' }
    $total = $script:WB_WIDTH + 1
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("$ESC[38;2;139;233;253m$left")
    for ($i = 0; $i -lt $total; $i++) {
        $pct = [int]([math]::Floor($i * 100 / [math]::Max(1, $total - 1)))
        if ($pct -lt 50) {
            $p = $pct * 2
            $r = 139 + (255 - 139) * $p / 100
            $g = 233 + (121 - 233) * $p / 100
            $b = 253 + (198 - 253) * $p / 100
        } else {
            $p = ($pct - 50) * 2
            $r = 255 + (189 - 255) * $p / 100
            $g = 121 + (147 - 121) * $p / 100
            $b = 198 + (249 - 198) * $p / 100
        }
        [void]$sb.Append("$ESC[38;2;$([int]$r);$([int]$g);$([int]$b)m═")
    }
    [void]$sb.Append("$ESC[38;2;189;147;249m$right$ESC[0m")
    $sb.ToString()
}

# --- Section: greeting -------------------------------------------------------
function _wb_greeting {
    $hour = (Get-Date).Hour
    if ($script:WB_LANG -eq 'en') {
        if     ($hour -ge 5  -and $hour -lt 11) { $greet = 'Good morning';   $emoji = "🌅" }
        elseif ($hour -ge 11 -and $hour -lt 18) { $greet = 'Good afternoon'; $emoji = "☀️ " }
        elseif ($hour -ge 18 -and $hour -lt 23) { $greet = 'Good evening';   $emoji = "🌆" }
        else                                    { $greet = 'Good night';     $emoji = "🌙" }
    } else {
        if     ($hour -ge 5  -and $hour -lt 11) { $greet = 'Guten Morgen'; $emoji = "🌅" }
        elseif ($hour -ge 11 -and $hour -lt 18) { $greet = 'Guten Tag';    $emoji = "☀️ " }
        elseif ($hour -ge 18 -and $hour -lt 23) { $greet = 'Guten Abend';  $emoji = "🌆" }
        else                                    { $greet = 'Gute Nacht';   $emoji = "🌙" }
    }
    $user = $env:USERNAME
    $c = $script:WB_C
    "$emoji  $($c.bold)$($c.orange)$greet$($c.reset), $($c.cyan)$user$($c.reset)!"
}

# --- Section: date / time ----------------------------------------------------
function _wb_datetime {
    $now = Get-Date
    if ($script:WB_LANG -eq 'en') {
        $culture = [System.Globalization.CultureInfo]::new('en-US')
    } else {
        $culture = [System.Globalization.CultureInfo]::new('de-DE')
    }
    $wday  = $culture.DateTimeFormat.GetDayName($now.DayOfWeek)
    $month = $culture.DateTimeFormat.GetMonthName($now.Month)
    $time  = $now.ToString('HH:mm:ss')
    $c = $script:WB_C
    "🗓️  $($c.purple)$wday$($c.reset), $($now.Day). $month $($now.Year)   $($c.green)⏰ $time$($c.reset)"
}

# --- Section: weather (wttr.in, cached) --------------------------------------
function _wb_cache_age {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 999999 }
    [int]((Get-Date) - (Get-Item $Path).LastWriteTime).TotalSeconds
}

function _wb_fetch_weather {
    $cache = Join-Path $script:WB_CACHE_DIR 'weather.txt'
    if (((_wb_cache_age $cache) -lt $script:WB_CACHE_TTL) -and ((Get-Item $cache -ErrorAction SilentlyContinue).Length -gt 0)) {
        return (Get-Content $cache -Raw).TrimEnd()
    }
    try {
        $uri = "https://wttr.in/$($script:WB_CITY)?format=%c|%t|%w|%h|%p|%C&lang=$($script:WB_LANG)"
        $raw = Invoke-RestMethod -Uri $uri -TimeoutSec 4 -ErrorAction Stop
        if ($raw) {
            Set-Content -Path $cache -Value $raw -Encoding UTF8 -NoNewline
            return ($raw -as [string]).TrimEnd()
        }
    } catch {}
    return $null
}

function _wb_fetch_forecast {
    $cache = Join-Path $script:WB_CACHE_DIR 'forecast.json'
    if (((_wb_cache_age $cache) -lt $script:WB_CACHE_TTL) -and ((Get-Item $cache -ErrorAction SilentlyContinue).Length -gt 0)) {
        try { return (Get-Content $cache -Raw | ConvertFrom-Json) } catch { return $null }
    }
    try {
        $json = Invoke-RestMethod -Uri "https://wttr.in/$($script:WB_CITY)?format=j1" -TimeoutSec 5 -ErrorAction Stop
        $json | ConvertTo-Json -Depth 8 | Set-Content -Path $cache -Encoding UTF8
        return $json
    } catch { return $null }
}

function _wb_weather_lines {
    if ($env:WELCOME_NO_WEATHER) { return @() }
    $c = $script:WB_C
    $current = _wb_fetch_weather
    if (-not $current) {
        return @("🌐 $($c.red)Wetter offline$($c.reset) — kein Netz oder wttr.in nicht erreichbar")
    }
    $parts = $current -split '\|'
    if ($parts.Count -lt 6) { return @("🌐 $($c.red)Wetter-Format unerwartet$($c.reset)") }
    $icon = $parts[0].Trim()
    $temp = $parts[1].Trim()
    $wind = $parts[2].Trim()
    $hum  = $parts[3].Trim()
    $prec = $parts[4].Trim()
    $cond = $parts[5].Trim()

    $lines = @()
    $lines += "$icon  $($c.bold)$($c.cyan)$($script:WB_CITY)$($c.reset) · $($c.orange)$temp$($c.reset) · 💨 $wind · 💧 $hum · ☔ $prec"
    if ($cond) { $lines += "$($c.comment)$cond$($c.reset)" }

    $fc = _wb_fetch_forecast
    if ($fc -and $fc.weather) {
        $series = @()
        $nowH = (Get-Date).Hour
        foreach ($day in $fc.weather[0..[math]::Min(1, $fc.weather.Count - 1)]) {
            $dayIdx = [Array]::IndexOf($fc.weather, $day)
            foreach ($h in $day.hourly) {
                $tH = [int]($h.time) / 100
                if ($dayIdx -eq 0 -and $tH -lt $nowH) { continue }
                $mm = 0.0; [double]::TryParse($h.precipMM, [ref]$mm) | Out-Null
                $series += [pscustomobject]@{
                    H = [int]$tH; T = [int]$h.tempC; R = [int]$h.chanceofrain; MM = $mm
                }
                if ($series.Count -ge 5) { break }
            }
            if ($series.Count -ge 5) { break }
        }
        if ($series.Count -gt 0) {
            $arrows = @(); $prev = $null
            foreach ($s in $series) {
                if ($null -eq $prev)        { $arr = '·' }
                elseif ($s.T -gt $prev)     { $arr = '↗' }
                elseif ($s.T -lt $prev)     { $arr = '↘' }
                else                        { $arr = '→' }
                $prev = $s.T
                $arrows += ('{0:00}h{1,3}°{2}' -f $s.H, $s.T, $arr)
            }
            $blocks = ' ▁▂▃▄▅▆▇█'
            $spark = -join ($series | ForEach-Object { $blocks[[math]::Min($blocks.Length - 1, [int]($_.R * 8 / 100))] })
            $avg = [int](($series | Measure-Object -Property R -Average).Average)
            $totalMm = ($series | Measure-Object -Property MM -Sum).Sum
            $lines += "📈 $($c.green)Trend:$($c.reset) $($arrows -join '  ')"
            $lines += "🌧️  $($c.cyan)Regen:$($c.reset) $($c.cyan)$spark $avg% Ø · $($totalMm.ToString('F1'))mm 15h$($c.reset)"
        }
    }
    $lines
}

# --- Section: system info ----------------------------------------------------
function _wb_sysinfo {
    $c = $script:WB_C
    $psVer = $PSVersionTable.PSVersion.ToString()
    $os = ''
    try {
        $cim = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        # Keep this short to fit alongside hostname (mirrors macOS "macOS Sequoia 15.x" length).
        if     ($cim.Caption -match 'Windows 11') { $os = 'Windows 11' }
        elseif ($cim.Caption -match 'Windows 10') { $os = 'Windows 10' }
        elseif ($cim.Caption -match 'Server')     { $os = ($cim.Caption -replace '^Microsoft ', '' -replace ' Standard| Datacenter| Essentials', '') }
        else                                      { $os = $cim.Caption.Replace('Microsoft ', '') }
        $os = "$os ($($cim.BuildNumber))"
    } catch { $os = [System.Environment]::OSVersion.VersionString }
    $host_ = $env:COMPUTERNAME
    if ($host_.Length -gt 16) { $host_ = $host_.Substring(0, 14) + '…' }
    "🐚 $($c.purple)Shell:$($c.reset) pwsh $psVer  ·  💻 $($c.pink)$os$($c.reset)  ·  🖥️  $host_"
}

# --- Tips list (same German tips as macOS welcome.zsh) -----------------------
$script:WB_TIPS = @(
    'Mit Strg+R die Shell-History rückwärts durchsuchen — fzf macht''s noch schöner.',
    'ESC+. fügt das letzte Argument des vorherigen Befehls ein.',
    'cd - wechselt zurück ins zuletzt verwendete Verzeichnis.',
    '!! wiederholt den letzten Befehl. sudo !! mit Sudo-Power.',
    'history | grep <muster> findet alte Befehle blitzschnell.',
    'Mit && verkettet man Befehle nur bei Erfolg, mit || bei Fehler.',
    'tldr <cmd> zeigt praxisnahe Beispiele zu jedem Tool.',
    'ripgrep (rg) ist meist 10x schneller als grep -r.',
    'fd ist die moderne Alternative zu find — schneller und mit defaults.',
    'z (zoxide) springt zu häufig genutzten Verzeichnissen per Fragment.',
    'btm (bottom) visualisiert Systemlast schöner als top.',
    'gh dash zeigt alle GitHub-PRs/Issues direkt im Terminal.',
    'git switch -c <branch> ist die moderne Alternative zu git checkout -b.',
    'git log --oneline --graph --all macht die Historie lesbar.',
    'git restore --staged <file> entpackt Stage-Änderungen ohne Reset-Risiken.',
    'jq ''.key | .[]'' parst JSON wie ein Profi.',
    'yq macht dasselbe für YAML.',
    'Strg+L löscht den Bildschirm schneller als clear.',
    'Strg+U löscht alles vor dem Cursor in der aktuellen Zeile.',
    'Strg+W löscht das Wort vor dem Cursor.',
    'diff <(cmd1) <(cmd2) vergleicht zwei Outputs direkt.',
    'tar -tf archive.tar.gz listet Inhalte ohne zu extrahieren.',
    'Pomodoro: 25 min konzentriert + 5 min Pause = produktive Stunde.',
    'Vergiss nicht: Kein Code ist sicherer Code als gelöschter Code.',
    'duf ist df mit besseren Farben und Format.',
    'starship ist ein schneller, schöner Cross-Shell-Prompt.',
    'lazygit gibt git eine wunderschöne TUI.',
    'fzf + Ctrl+T = interaktive Datei-Suche überall.',
    'eza ist ein schöneres ls mit Icons und Git-Status.',
    'Mit `Show-Help` siehst du alle Profile-Befehle auf einen Blick.'
)

function _wb_tip_text {
    $idx = (Get-Date).DayOfYear % $script:WB_TIPS.Count
    $script:WB_TIPS[$idx]
}

function _wb_tip_block {
    $c = $script:WB_C
    $label = "💡 $($c.bold)$($c.yellow)Tipp des Tages:$($c.reset)"
    $labelVisible = 18
    $tip = _wb_tip_text
    $max = $script:WB_WIDTH
    $indent = '    '
    $words = $tip -split ' '
    $cur = ''; $first = $true
    $out = @()
    foreach ($w in $words) {
        $trial = if (-not $cur) { $w } else { "$cur $w" }
        $trialLen = Get-WelcomeStrLen $trial
        if ($first) { $avail = $max - $labelVisible - 1 } else { $avail = $max - $indent.Length }
        if ($trialLen -gt $avail -and $cur) {
            if ($first) { $out += "$label $cur"; $first = $false }
            else        { $out += "$indent$cur" }
            $cur = $w
        } else {
            $cur = $trial
        }
    }
    if ($cur) {
        if ($first) { $out += "$label $cur" } else { $out += "$indent$cur" }
    }
    $out
}

# --- Public entry point ------------------------------------------------------
function Global:Show-Welcome {
    Write-Host ''
    Write-Host (_wb_border 'top')
    Write-Host (_wb_line (_wb_greeting) 'cyan')
    Write-Host (_wb_line (_wb_datetime) 'cyan')

    Write-Host (_wb_sep 'pink')
    if (-not $env:WELCOME_NO_WEATHER) {
        $wlines = _wb_weather_lines
        foreach ($ln in $wlines) { Write-Host (_wb_line $ln 'pink') }
        Write-Host (_wb_sep 'purple')
    }

    Write-Host (_wb_line (_wb_sysinfo) 'purple')
    Write-Host (_wb_sep 'comment')

    foreach ($ln in (_wb_tip_block)) { Write-Host (_wb_line $ln 'comment') }
    Write-Host (_wb_border 'bottom')
    Write-Host ''
}

# --- Run on load -------------------------------------------------------------
# Skip the auto-render when output is piped / redirected (scripts, captured
# sessions). Show-Welcome stays callable, just not automatic in that case.
if (-not [Console]::IsOutputRedirected) {
    if ((-not $env:WELCOME_NO_FASTFETCH) -and (Test-Command 'fastfetch')) {
        try { fastfetch } catch {}
    }
    if (-not $env:WELCOME_NO_BOX) {
        try { Show-Welcome } catch {
            Write-Host "Welcome box failed: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
}
