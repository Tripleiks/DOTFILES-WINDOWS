# Ultimate PowerShell Profile

A friendly, fast PowerShell setup for Windows. Once installed, every PowerShell window you open gets:

- A nicer prompt that shows your folder, your git branch, and whether the last command worked
- Useful shortcuts (`gs` for `git status`, `..` to go up a folder, `mkcd` to "make a folder and jump into it", and many more)
- Modern replacements for old commands (faster file search, prettier file listings, syntax-coloured text viewer)
- Smart history (start typing a command and hit the up-arrow to find it again)
- A `Show-Help` command that lists everything available

You don't have to memorise any of it. Type `Show-Help` in any new shell.

---

## Who is this for

Anyone on the team who wants a comfortable PowerShell. You do not need to be a "shell person". Installing it is one command, and nothing about how PowerShell normally works is changed. Everything you get is added on top.

---

## How to install

```pwsh
git clone https://github.com/<your-org>/DOTFILES-WINDOWS C:\GitHub\DOTFILES-WINDOWS
cd C:\GitHub\DOTFILES-WINDOWS\PowerShell
.\setup.ps1
```

Then open a new PowerShell window. You should see the new prompt and a one-line hint telling you to type `Show-Help`.

**Safe to re-run.** The setup skips anything you already have, so running it again is harmless.

Useful flags:

| Flag         | What it does                                                          |
| ------------ | --------------------------------------------------------------------- |
| `-Minimal`   | Only install the prompt + zoxide; skip the modern CLI tools and font  |
| `-SkipFont`  | Do not install the JetBrains Mono Nerd Font                           |
| `-NoAdmin`   | Set the telemetry opt-out variables for the current user only         |

If you have already installed the tools yourself and only want to wire the profile into your PowerShell paths:

```pwsh
.\install.ps1            # current user (no admin needed)
.\install.ps1 -Machine   # all users on this PC (run elevated)
```

---

## What gets installed

The setup script installs (or skips, if already present):

**Tools (via winget)**

*Always installed*
- `starship` - the primary prompt (Dracula theme ships in `themes/starship.toml`)
- `oh-my-posh` - fallback prompt if starship is missing
- `zoxide` - `z folder-fragment` jumps to any folder you have visited
- `fastfetch` - neofetch successor; prints a system summary on shell start

*Skipped with `-Minimal`*
- `eza`, `bat`, `ripgrep` (`rg`), `fd` - modern listings, paging, searching
- `fzf` - fuzzy finder (Ctrl+T for files, Ctrl+R for history)
- `delta` - colourful git diffs in your pager
- `lazygit` - full-screen git interface (alias: `lg`)
- `difftastic` - syntax-aware diff (`difft`)
- `gsudo` - a `sudo` for Windows
- `bottom` - system monitor (alias: `top` -> `btm`)
- `gh` - GitHub CLI
- `jq` / `yq` - query/transform JSON / YAML
- `dust` / `duf` - prettier `du` / `df` (the built-in `du`/`df` use these automatically when installed)
- `xh` - friendlier `curl` / `Invoke-WebRequest`
- `glow` - render markdown in the terminal
- `hyperfine` - benchmark commands
- `tldr` - one-screen cheat sheets for any command

**PowerShell modules (core)**
- `PSReadLine` - autocomplete and history search
- `Terminal-Icons` - file icons in directory listings
- `posh-git` - git tab completion
- `PSFzf` - Ctrl+T file / Ctrl+R history fuzzy pickers

**PowerShell modules (enterprise admin — skip with `-NoAdminModules`)**

For managing M365, Azure, and hybrid AD environments from this workstation:

- `Microsoft.Graph` - the modern unified Graph SDK (replaces deprecated AzureAD and MSOnline)
- `Az` - the Azure PowerShell umbrella (Az.Accounts, Az.Resources, Az.Compute, …)
- `ExchangeOnlineManagement` - Exchange Online / EOP / Security & Compliance / Defender for O365
- `MicrosoftTeams` - Teams admin
- `Microsoft.Online.SharePoint.PowerShell` - SharePoint Online admin
- `PnP.PowerShell` - community PnP module for M365 / SharePoint / Teams / Graph
- `PSWindowsUpdate` - manage Windows Update from PowerShell
- `ImportExcel` - read/write Excel without needing Excel installed (great for reports)

Note: `AzureAD` and `MSOnline` are **deprecated** by Microsoft and intentionally not installed. Use `Microsoft.Graph` for the same functionality.

**RSAT capabilities (only when running setup elevated; skip with `-NoRSAT`)**

For managing on-premises and hybrid resources from this workstation:

- `Rsat.ActiveDirectory.DS-LDS.Tools` - Active Directory module + ADUC / ADSI Edit
- `Rsat.Dns.Tools` - DNS Manager + DnsServer module
- `Rsat.DHCP.Tools` - DHCP module
- `Rsat.GroupPolicy.Management.Tools` - GPMC + GroupPolicy module
- `Rsat.ServerManager.Tools` - Server Manager
- `Rsat.CertificateServices.Tools` - Certificate Authority tools
- `Rsat.FileServices.Tools` - File Server tools

**Font**
- JetBrains Mono Nerd Font - so prompt icons render correctly. After install, set your terminal font to it (in Windows Terminal: Settings -> Profile -> Appearance -> Font face).

---

## Command cheat sheet

Run `Show-Help` in a shell for the live, colour-coded version. Below is the full reference.

### Getting around

| Type this                | What it does                                                  |
| ------------------------ | ------------------------------------------------------------- |
| `z <fragment>`           | Jump to a folder you have visited that matches the fragment   |
| `..` / `...` / `....`    | Go up 1, 2, or 3 folders                                      |
| `~`                      | Go to your home folder                                        |
| `docs` / `dl`            | Go to Documents / Downloads                                   |
| `dot` / `ghub`           | Go to the dotfiles folder / `C:\GitHub`                       |
| `groot`                  | Jump to the root of the git repo you are currently inside     |

### Listing files

| Type this              | What it does                                          |
| ---------------------- | ----------------------------------------------------- |
| `ls`                   | Nice file list with icons (if eza is installed)       |
| `ll` / `la`            | Long list / show hidden files too                     |
| `lt` / `lta`           | Tree view (2 levels / 4 levels with hidden)           |
| `tree [path] [depth]`  | Directory tree                                        |
| `cat <file>`           | View a file with syntax colours (uses bat)            |
| `less <file>`          | View a file page-by-page                              |

### Files and folders

| Type this                          | What it does                                       |
| ---------------------------------- | -------------------------------------------------- |
| `touch <file>`                     | Create empty file, or update its modified time     |
| `mkcd <dir>`                       | Create a folder and jump straight into it          |
| `trash <path>`                     | Move to Recycle Bin (recoverable!)                 |
| `ff <name>`                        | Find files by name                                 |
| `grep <pattern> [path]`            | Search inside files (uses ripgrep if available)    |
| `head <file>` / `tail <file>`      | Show first / last 10 lines (`-Follow` for live)    |
| `sed <file> <find> <replace>`      | Quick in-place text replace                        |
| `which <cmd>`                      | Show where a command lives on disk                 |
| `du [path]`                        | How big is each folder?                            |
| `df`                               | How much space is free on my drives?               |
| `extract <archive>`                | Unzip anything (zip / tar.gz / 7z / and more)      |
| `sha256 <file>` / `md5 <file>`     | File hash                                          |

### System and processes

| Type this              | What it does                                                  |
| ---------------------- | ------------------------------------------------------------- |
| `uptime`               | How long since the last reboot                                |
| `sysinfo`              | OS, CPU, RAM, and shell summary                               |
| `top`                  | Interactive monitor (`bottom`/`btm`) or top-20 snapshot       |
| `pgrep <name>`         | List running processes whose name matches a pattern           |
| `pkill <name>`         | Stop matching processes (asks before each one)                |
| `k9 <name>`            | Force-stop all matching processes (no prompt)                 |
| `sudo <command>`       | Run as administrator (uses gsudo if installed)                |
| `env [filter]`         | List environment variables (with optional wildcard filter)    |
| `path`                 | Show the contents of `PATH` as a numbered list                |

### Network

| Type this                  | What it does                                              |
| -------------------------- | --------------------------------------------------------- |
| `myip`                     | Your local IPv4 addresses                                 |
| `publicip`                 | What the internet sees you as (calls api.ipify.org)       |
| `portcheck <host> <port>`  | Is that port reachable? (with timeout)                    |
| `listening`                | Which TCP ports this machine is listening on, and who     |
| `dig <name> [-Type]`       | DNS lookup                                                |
| `netinfo`                  | Physical network adapter info                             |

### Clipboard

| Type this              | What it does                                  |
| ---------------------- | --------------------------------------------- |
| `<command> \| cb`      | Send the output of a command to the clipboard |
| `paste`                | Paste the clipboard to stdout                 |
| `cbf <file>`           | Copy a whole file's contents to the clipboard |

### Git shortcuts

| Type this                          | What it does                                          |
| ---------------------------------- | ----------------------------------------------------- |
| `gs` / `gss`                       | `git status` / short status                           |
| `ga <files>` / `gaa`               | `git add ...` / `git add -A`                          |
| `gc` / `gcm "msg"` / `gca`         | commit / commit -m / commit --amend                   |
| `gcom "msg"`                       | Add everything and commit with a message (no push)    |
| `lazyg "msg"`                      | Add everything, commit, and push                      |
| `gp` / `gpush` / `gpull` / `gf`    | push / push / pull / fetch --all --prune              |
| `gco` / `gsw` / `gswc <name>`      | checkout / switch / switch -c (create new branch)     |
| `gb` / `gbd` / `gbdf`              | list / delete / force-delete branch                   |
| `gd` / `gdc`                       | diff / diff of staged changes                         |
| `glog` / `gloga` / `gll`           | pretty log / all branches / detailed                  |
| `gst` / `gstp` / `gstl`            | stash / stash pop / stash list                        |
| `gcl <url>`                        | clone                                                 |
| `gremotes` / `groot`               | list remotes / cd to repo root                        |
| `lg`                               | lazygit - full-screen git TUI (if installed)          |

### Profile management

| Type this                  | What it does                                            |
| -------------------------- | ------------------------------------------------------- |
| `Show-Help`                | Print the full reference                                |
| `ep` / `Edit-Profile`      | Open the profile in your editor                         |
| `epd`                      | Open the profile folder in your editor                  |
| `reload`                   | Re-load the profile after edits                         |
| `Update-Profile`           | `git pull` the dotfiles repo and reload                 |
| `edit <file>`              | Open a file in your preferred editor                    |

### External tools (installed by `setup.ps1`, call directly)

| Type this                          | What it does                                          |
| ---------------------------------- | ----------------------------------------------------- |
| `tldr <cmd>`                       | One-screen cheat sheet for any command                |
| `jq` / `yq`                        | Query and transform JSON / YAML                       |
| `xh <url>`                         | Friendlier alternative to `curl` / `Invoke-WebRequest` |
| `glow <file.md>`                   | Render Markdown in the terminal                       |
| `difft <a> <b>`                    | Syntax-aware diff (difftastic). Try `git config --global diff.external difft` |
| `hyperfine <cmd>`                  | Benchmark a command's runtime                         |

### Startup look & feel

- **Starship prompt** in Dracula colors, shipped in `themes/starship.toml`. Switch engines with `$env:PROMPT_ENGINE = 'starship' | 'posh' | 'none'`.
- **fastfetch** prints a system summary every time you open a shell.
- **Welcome box** below fastfetch shows a greeting, date/time in German, weather for Hamburg (cached 5 min), system info, and a daily tip. Tweak via env vars:

| Env var | Default | What it does |
|---|---|---|
| `WELCOME_NO_FASTFETCH` | unset | Skip fastfetch on shell start |
| `WELCOME_NO_BOX` | unset | Skip the welcome box |
| `WELCOME_NO_WEATHER` | unset | Keep the box but drop the weather block |
| `WELCOME_CITY` | `Hamburg` | City for the wttr.in lookup |
| `WELCOME_LANG` | `de` | `de` or `en` |
| `WELCOME_WIDTH` | `72` | Inner width of the box |

Run `Show-Welcome` to reprint the box on demand.

### Keyboard niceties

- Start typing, then hit **Up / Down** - history is filtered to what you typed
- **F7** - history grid picker
- **Ctrl+T** - fuzzy file picker (after PSFzf has loaded)
- **Ctrl+R** - fuzzy history picker
- **Tab** - menu-style completion
- **Ctrl+W** - delete the previous word
- **Ctrl+Z** / **Ctrl+Y** - undo / redo

---

## How the files are organised

```
PowerShell/
  Microsoft.PowerShell_profile.ps1    <- the entry point; loads everything below
  profile/                            <- modular files, loaded in number order
    00-core.ps1                       <- foundation, helpers used by other modules
    10-psreadline.ps1                 <- nicer command line (history, colours, keys)
    20-prompt.ps1                     <- the prompt (oh-my-posh + zoxide)
    30-aliases.ps1                    <- modern command replacements
    40-fs.ps1                         <- file / folder shortcuts
    50-system.ps1                     <- system info, processes, profile mgmt
    60-git.ps1                        <- git shortcuts
    70-net.ps1                        <- network tools
    80-clipboard.ps1                  <- clipboard helpers
    90-deferred.ps1                   <- slow-to-load extras, run after first prompt
    99-help.ps1                       <- the Show-Help command
  themes/
    ultimate.omp.json                 <- prompt theme for oh-my-posh
  install.ps1                         <- wires the profile into your PowerShell paths
  setup.ps1                           <- installs the tools (run this first)
```

**Adding your own bits.** Drop a new file in `profile/` named for example `85-mine.ps1`. The number controls load order. It will be picked up automatically next time you start PowerShell or run `reload`.

---

## Customising

- **Change the prompt** - edit `themes/ultimate.omp.json`, or set `$env:POSH_THEME` to point at a different `.omp.json` file
- **Change your editor** - set `$env:EDITOR` to `code`, `nvim`, `notepad`, etc.
- **See load timing** - set `$env:PROFILE_VERBOSE=1` before starting PowerShell
- **Inspect load errors** - if a module fails, `$ProfileLoadErrors` shows what went wrong (other modules still loaded)

---

## Troubleshooting

**The prompt shows boxes or question marks instead of icons.**
Your terminal font does not have the icon glyphs. Set the font to **JetBrains Mono Nerd Font** (or any Nerd Font). In Windows Terminal: Settings -> your profile -> Appearance -> Font face.

**`Show-Help` says "command not found".**
The profile did not load. Open a brand-new PowerShell window. If it still doesn't work, check `$ProfileLoadErrors` for the cause.

**I see "running scripts is disabled on this system".**
Run this once in an admin shell:
```pwsh
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**I want to undo the install.**
`install.ps1` backed up any pre-existing profile files to `*.bak.<timestamp>` next to them. Restore one of those, or delete `profile.ps1` in your PowerShell folder. The files in the dotfiles repo are not touched - only the small "stub" files that point at them.

---

## What this profile does NOT do

- **No phoning home.** Updates happen only when you run `Update-Profile`. There is no auto-update.
- **No system-wide changes** beyond two `*_TELEMETRY_OPTOUT=1` environment variables.
- **No surprises.** `-Minimal` skips every modern CLI tool. Everything the setup installs is listed above.
