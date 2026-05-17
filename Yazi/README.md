# Yazi

Config for [Yazi](https://yazi-rs.github.io), a blazing-fast terminal file
manager. The repo holds the source of truth; `install.ps1` symlinks each file
into `%APPDATA%\yazi\config\` so edits to this folder take effect immediately.

## Layout

```
Yazi/
├── config/
│   ├── yazi.toml      # main settings: layout, sort, preview, openers
│   ├── keymap.toml    # keybinding overrides (empty starter)
│   └── theme.toml     # theme / flavor (empty starter)
├── install.ps1        # symlinks config/* into %APPDATA%\yazi\config\
└── README.md
```

## Install

`PowerShell\setup.ps1` installs Yazi via winget and invokes this folder's
`install.ps1` automatically. To run just this piece:

```powershell
.\install.ps1            # symlinks the config files (needs Developer Mode or admin)
.\install.ps1 -Force     # overwrite without making .bak backups
```

The Windows symlink requires either:

- **Developer Mode** enabled (Settings → Privacy & security → For developers), or
- the script run from an **elevated** PowerShell window.

The installer does not silently fall back to copying — that would break the
"edit in repo, see it everywhere" model.

## Shell integration

`PowerShell\profile\45-yazi.ps1` defines a `y` function that runs Yazi and
then `cd`s into whatever directory you were browsing when you quit. Use
`yazi` if you want the plain command, `y` if you want the cd-on-exit
behavior.

## Updating

```powershell
git pull            # in the repo root — no re-link needed, the files are linked, not copied
```

If you want to add plugins or flavors, install them with
`ya pkg add <repo>:<pkg>` — they land under `%APPDATA%\yazi\` outside this
folder and aren't managed by `install.ps1`.
