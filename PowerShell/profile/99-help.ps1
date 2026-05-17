# =============================================================================
# 99-help.ps1 - The Show-Help command
#
# WHAT THIS IS
#   A colorful cheat sheet of everything this profile adds. Type:
#       Show-Help
#   in any new shell to see it. The profile also prints a one-line hint
#   on startup reminding you about it.
#
#   This file ONLY defines the command. It runs nothing on load (other than
#   the hint line), so it's cheap to include.
# =============================================================================

function Global:Show-Help {
    $usePSStyle = $Global:IsPS7 -and (Get-Variable PSStyle -ErrorAction SilentlyContinue)
    if ($usePSStyle) {
        $title   = $PSStyle.Foreground.BrightMagenta
        $section = $PSStyle.Foreground.BrightCyan
        $command = $PSStyle.Foreground.BrightGreen
        $desc    = $PSStyle.Foreground.BrightWhite
        $accent  = $PSStyle.Foreground.BrightYellow
        $dim     = $PSStyle.Foreground.BrightBlack
        $reset   = $PSStyle.Reset
    } else {
        $esc     = [char]27
        $title   = "$esc[95m"; $section = "$esc[96m"; $command = "$esc[92m"
        $desc    = "$esc[97m"; $accent  = "$esc[93m"; $dim     = "$esc[90m"
        $reset   = "$esc[0m"
    }

    @"
${title}❯ Ultimate PowerShell Profile — Quick Reference${reset}
${dim}─────────────────────────────────────────────────────────────${reset}

${section}Profile management${reset}
  ${command}ep / Edit-Profile${reset}        ${accent}→${reset} ${desc}edit main profile in `$EDITOR${reset}
  ${command}epd / Open-ProfileDir${reset}    ${accent}→${reset} ${desc}open profile directory${reset}
  ${command}reload / Reload-Profile${reset}  ${accent}→${reset} ${desc}re-dot-source the profile${reset}
  ${command}Update-Profile${reset}           ${accent}→${reset} ${desc}git pull `$DOTFILES_ROOT and reload${reset}

${section}Navigation${reset}
  ${command}z <pattern>${reset}              ${accent}→${reset} ${desc}zoxide smart cd${reset}
  ${command}.. / ... / ....${reset}          ${accent}→${reset} ${desc}go up 1/2/3 directories${reset}
  ${command}~${reset}                        ${accent}→${reset} ${desc}home directory${reset}
  ${command}docs / dl / dot / ghub${reset}   ${accent}→${reset} ${desc}Documents / Downloads / dotfiles / GitHub root${reset}
  ${command}groot${reset}                    ${accent}→${reset} ${desc}cd to current git repo root${reset}

${section}Listing & files (eza if installed)${reset}
  ${command}ls / ll / la / lt / lta${reset}  ${accent}→${reset} ${desc}list / long / all / tree / deep tree${reset}
  ${command}tree [path] [depth]${reset}      ${accent}→${reset} ${desc}directory tree${reset}
  ${command}cat / less${reset}               ${accent}→${reset} ${desc}bat-powered viewers (if installed)${reset}
  ${command}touch <file...>${reset}          ${accent}→${reset} ${desc}create or update mtime${reset}
  ${command}mkcd <dir>${reset}               ${accent}→${reset} ${desc}mkdir + cd${reset}
  ${command}trash <path>${reset}             ${accent}→${reset} ${desc}send to Recycle Bin${reset}
  ${command}ff <name>${reset}                ${accent}→${reset} ${desc}find files by name (fd/Get-ChildItem)${reset}
  ${command}grep <pattern> [path]${reset}    ${accent}→${reset} ${desc}rg if installed, else Select-String${reset}
  ${command}head / tail [-Follow] <file>${reset} ${accent}→${reset} ${desc}first / last 10 lines${reset}
  ${command}sed <file> <find> <repl>${reset} ${accent}→${reset} ${desc}in-place text replace${reset}
  ${command}which <name>${reset}             ${accent}→${reset} ${desc}locate command${reset}
  ${command}du [path] [-Summary]${reset}     ${accent}→${reset} ${desc}folder sizes${reset}
  ${command}df${reset}                       ${accent}→${reset} ${desc}disk free${reset}
  ${command}extract <archive>${reset}        ${accent}→${reset} ${desc}zip/tar/7z extractor${reset}
  ${command}unzip <file>${reset}             ${accent}→${reset} ${desc}Expand-Archive${reset}
  ${command}sha256 / md5 <file>${reset}      ${accent}→${reset} ${desc}file hash${reset}

${section}System & process${reset}
  ${command}uptime${reset}                   ${accent}→${reset} ${desc}boot time + duration${reset}
  ${command}sysinfo${reset}                  ${accent}→${reset} ${desc}host / OS / CPU / memory summary${reset}
  ${command}top${reset}                      ${accent}→${reset} ${desc}interactive monitor (bottom / btm) or top-20 snapshot${reset}
  ${command}pgrep <regex>${reset}            ${accent}→${reset} ${desc}list matching processes${reset}
  ${command}pkill <regex> [-Force]${reset}   ${accent}→${reset} ${desc}interactive kill${reset}
  ${command}k9 <regex>${reset}               ${accent}→${reset} ${desc}force kill all matches${reset}
  ${command}sudo [command]${reset}           ${accent}→${reset} ${desc}elevate (uses gsudo if installed)${reset}
  ${command}env [filter]${reset}             ${accent}→${reset} ${desc}list environment variables${reset}
  ${command}path${reset}                     ${accent}→${reset} ${desc}print \$PATH as a list${reset}

${section}Networking${reset}
  ${command}myip${reset}                     ${accent}→${reset} ${desc}local IPv4 addresses${reset}
  ${command}publicip${reset}                 ${accent}→${reset} ${desc}public IP (calls api.ipify.org)${reset}
  ${command}portcheck <host> <port>${reset}  ${accent}→${reset} ${desc}TCP connect probe${reset}
  ${command}listening${reset}                ${accent}→${reset} ${desc}listening TCP ports + owners${reset}
  ${command}dig <name> [-Type]${reset}       ${accent}→${reset} ${desc}DNS lookup${reset}
  ${command}netinfo${reset}                  ${accent}→${reset} ${desc}physical adapters${reset}

${section}Clipboard${reset}
  ${command}cb${reset}                       ${accent}→${reset} ${desc}pipe stdin → clipboard${reset}
  ${command}paste${reset}                    ${accent}→${reset} ${desc}clipboard → stdout${reset}
  ${command}cbf <file>${reset}               ${accent}→${reset} ${desc}copy file contents to clipboard${reset}

${section}Git${reset}
  ${command}gs / gss${reset}                 ${accent}→${reset} ${desc}status / short status${reset}
  ${command}ga / gaa${reset}                 ${accent}→${reset} ${desc}add / add -A${reset}
  ${command}gc / gcm <msg> / gca${reset}     ${accent}→${reset} ${desc}commit / -m / --amend${reset}
  ${command}gcom <msg>${reset}               ${accent}→${reset} ${desc}add -A + commit -m${reset}
  ${command}lazyg <msg>${reset}              ${accent}→${reset} ${desc}add -A + commit + push${reset}
  ${command}gp / gpush / gpull / gf${reset}  ${accent}→${reset} ${desc}push / pull / fetch --all --prune${reset}
  ${command}gcl <url>${reset}                ${accent}→${reset} ${desc}clone${reset}
  ${command}gco / gsw / gswc <br>${reset}    ${accent}→${reset} ${desc}checkout / switch / switch -c${reset}
  ${command}gb / gbd / gbdf${reset}          ${accent}→${reset} ${desc}branch / delete / force-delete${reset}
  ${command}gd / gdc${reset}                 ${accent}→${reset} ${desc}diff / diff --cached${reset}
  ${command}glog / gloga / gll${reset}       ${accent}→${reset} ${desc}graph log / all / pretty${reset}
  ${command}gst / gstp / gstl${reset}        ${accent}→${reset} ${desc}stash / pop / list${reset}
  ${command}gr / grh / grs${reset}           ${accent}→${reset} ${desc}reset / reset --hard / restore${reset}
  ${command}gremotes / groot${reset}         ${accent}→${reset} ${desc}list remotes / cd repo root${reset}
  ${command}lg${reset}                       ${accent}→${reset} ${desc}lazygit — full-screen git TUI (if installed)${reset}

${section}Editor & misc${reset}
  ${command}edit <file>${reset}              ${accent}→${reset} ${desc}open in \$EDITOR (nvim/code/notepad)${reset}
  ${command}F7 (in PSReadLine)${reset}       ${accent}→${reset} ${desc}history grid picker${reset}
  ${command}Ctrl+t / Ctrl+r (with PSFzf)${reset} ${accent}→${reset} ${desc}file / history fuzzy pick${reset}

${section}External tools (installed by setup.ps1; call directly)${reset}
  ${command}tldr <cmd>${reset}               ${accent}→${reset} ${desc}one-screen cheat sheet for any command${reset}
  ${command}jq / yq${reset}                  ${accent}→${reset} ${desc}query / transform JSON / YAML${reset}
  ${command}xh <url>${reset}                 ${accent}→${reset} ${desc}friendlier curl / Invoke-WebRequest${reset}
  ${command}glow <file.md>${reset}           ${accent}→${reset} ${desc}render markdown in the terminal${reset}
  ${command}difft <a> <b>${reset}            ${accent}→${reset} ${desc}syntax-aware diff (difftastic)${reset}
  ${command}hyperfine <cmd>${reset}          ${accent}→${reset} ${desc}benchmark a command${reset}

${dim}─────────────────────────────────────────────────────────────${reset}
${dim}Type Show-Help to print this again. Set \$env:PROFILE_VERBOSE=1${reset}
${dim}to see load timing on next shell start.${reset}
"@
}

# The welcome box (95-welcome.ps1) already surfaces Show-Help via its tip-of-the-day
# pool. Only print the standalone hint when the welcome box is suppressed.
if ($env:WELCOME_NO_BOX) {
    Write-Host "Type 'Show-Help' for a quick reference." -ForegroundColor DarkGray
}
