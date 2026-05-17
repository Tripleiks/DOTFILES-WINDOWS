# =============================================================================
# 60-git.ps1 - Git command shortcuts
#
# WHAT THIS GIVES YOU
#   Short aliases for the git commands you type all day. A few favorites:
#     gs                 -> git status                (gss = short status)
#     gaa                -> git add -A
#     gcm "msg"          -> git commit -m "msg"
#     gcom "msg"         -> add everything + commit  (no push)
#     lazyg "msg"        -> add + commit + push       (when you trust the diff)
#     gp / gpull / gf    -> push / pull / fetch --all --prune
#     gco / gsw / gswc   -> checkout / switch / switch -c (new branch)
#     glog / gll         -> pretty git log
#     gst / gstp         -> stash / stash pop
#     groot              -> jump to repo root
#
#   Tab-completion for git commands and branches is loaded later by posh-git
#   (see 90-deferred.ps1).
#
#   Note: a few built-in PS aliases (gc/gp/gcm) are removed so we can reuse
#   the names for git. Get-Content / Get-Command still work by full name.
# =============================================================================

if (-not (Test-Command 'git')) { return }

# Built-in aliases beat functions in PS resolution order, so drop the ones
# we want to reuse for git shortcuts. Removed: gc (Get-Content), gp
# (Get-ItemProperty), gcm (Get-Command). Get-Content / Get-ItemProperty /
# Get-Command remain available by their full names.
foreach ($a in 'gc','gp','gcm') {
    if (Get-Alias $a -ErrorAction SilentlyContinue) {
        Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue
    }
}

# Core CTT-compatible shortcuts.
function Global:gs    { git status @args }
function Global:gss   { git status -s @args }                      # short status
function Global:ga    { git add @args }
function Global:gaa   { git add -A @args }
function Global:gp    { git push @args }
function Global:gpush { git push @args }
function Global:gpull { git pull @args }
function Global:gf    { git fetch --all --prune @args }
function Global:gcl   { git clone @args }

# Commit shortcuts.
function Global:gc    { git commit -v @args }                      # commit, opens $EDITOR
function Global:gcm   { git commit -m @args }                      # commit -m "..."
function Global:gca   { git commit --amend @args }
function Global:gcom {
    # CTT semantics — add everything + commit with message.
    git add -A
    git commit -m ($args -join ' ')
}
function Global:lazyg {
    git add -A
    git commit -m ($args -join ' ')
    git push
}

# Branches / checkout / switch.
function Global:gco   { git checkout @args }
function Global:gsw   { git switch @args }
function Global:gswc  { git switch -c @args }                      # new branch
function Global:gb    { git branch @args }
function Global:gbd   { git branch -d @args }
function Global:gbdf  { git branch -D @args }   # force-delete (gbD would collide with gbd in case-insensitive PS)

# Diff & log.
function Global:gd    { git diff @args }
function Global:gdc   { git diff --cached @args }
function Global:glog  { git log --oneline --decorate --graph @args }
function Global:gloga { git log --oneline --decorate --graph --all @args }
function Global:gll   { git log --pretty=format:'%C(yellow)%h%C(reset) %C(blue)%ad%C(reset) %C(green)%an%C(reset) %s%C(red)%d%C(reset)' --date=short -n 30 @args }

# Stash.
function Global:gst   { git stash @args }
function Global:gstp  { git stash pop @args }
function Global:gstl  { git stash list @args }

# Reset / restore.
function Global:gr    { git reset @args }
function Global:grh   { git reset --hard @args }
function Global:grs   { git restore @args }

# Remote / repo intel.
function Global:gremotes { git remote -v @args }
function Global:groot    { Set-Location (git rev-parse --show-toplevel) }

# Jump to GitHub root (CTT used `g` for this; we use `ghub` to avoid clashing
# with the gh CLI directory-jump function in 50-system.ps1).
function Global:ghub { Set-Location $Global:GITHUB_ROOT }

# `lg` — full-screen git TUI. Only defined if lazygit is installed.
if (Test-Command 'lazygit') {
    function Global:lg { lazygit @args }
}
