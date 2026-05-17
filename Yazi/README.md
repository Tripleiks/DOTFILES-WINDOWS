# Yazi

Config for [Yazi](https://yazi-rs.github.io), a blazing-fast terminal file
manager. The repo holds the source of truth; `install.ps1` symlinks each file
and plugin into `%APPDATA%\yazi\config\` so edits in this folder take effect
on the next yazi launch.

## Layout

```
Yazi/
├── config/
│   ├── yazi.toml      # main settings: layout, sort, preview, plugin wiring
│   ├── keymap.toml    # keybinding overrides (empty starter)
│   └── theme.toml     # theme / flavor (empty starter)
├── plugins/
│   └── chafa-preview.yazi/
│       └── main.lua   # image previewer that shells out to chafa
├── install.ps1        # symlinks config/* and plugins/* into %APPDATA%\yazi\config\
└── README.md
```

## Install

`PowerShell\setup.ps1` installs Yazi and chafa via winget and invokes this
folder's `install.ps1` automatically. To run just this piece:

```powershell
.\install.ps1            # symlinks config files + plugin dirs (needs Developer Mode or admin)
.\install.ps1 -Force     # overwrite without making .bak backups
```

The Windows symlink requires either:

- **Developer Mode** enabled (Settings → Privacy & security → For developers), or
- the script run from an **elevated** PowerShell window.

The installer does not silently fall back to copying — that would break the
"edit in repo, see it everywhere" model.

## Shell integration

`PowerShell\profile\45-yazi.ps1` does three things on profile load:

1. Sets `$env:YAZI_FILE_ONE` to Git for Windows' `file.exe` so yazi can
   detect MIME types (yazi calls `file -bL --mime-type` to pick a
   previewer; without that binary every preview falls back to the
   "File Type Classification" stub).
2. Prepends the real `chafa.exe` install directory to `$env:Path`. Winget
   only ships a zero-length `SymbolicLink` shim in `WinGet\Links\` which
   `CreateProcessW` does not follow, so yazi's spawned child can't reach
   chafa via the shim alone. The profile points PATH at the real exe.
3. Defines `y` — runs `yazi` and then `cd`s into the directory you were
   last browsing when you quit. Use `yazi` if you want the plain command,
   `y` if you want the cd-on-exit behavior.

## Image previews

Yazi auto-picks the image protocol from the terminal's DA1 capability
response. Windows Terminal v1.22+ advertises Sixel, so yazi picks the
sixel driver — but WT's sixel renderer does not visibly paint the data in
yazi's preview pane (the bytes are emitted, the cell stays blank).

The `chafa-preview` plugin bypasses yazi's image driver entirely:
`yazi.toml` registers it as a `[[plugin.prepend_previewers]]` for
`image/*`, so it intercepts image previews before the built-in driver runs
and emits chafa's ANSI/Unicode-block rendering instead. Lower fidelity
than sixel/kitty/iTerm protocols, but works in every terminal.

## Updating

```powershell
git pull            # in the repo root — no re-link needed, the files are linked, not copied
```

If you want to add plugins or flavors, install them with
`ya pkg add <repo>:<pkg>` — they land in `%APPDATA%\yazi\config\plugins\`
alongside our vendored ones and aren't managed by `install.ps1`.
