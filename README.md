# Espanso Sync Template

Cross-platform espanso snippet manager. Edit once, sync everywhere via GitHub.

## First time setup

1. Create a **GitHub account** if you don't have one
2. Create a **private repo** (e.g. `espanso_sync`) — this is where your snippets will live
3. Run the setup script on each PC

## Setting up on a new PC

### Linux
```bash
curl -o setup.sh https://raw.githubusercontent.com/mdragusm/espanso-sync-template/main/espanso_setup.sh && bash setup.sh
```

### Windows
Open PowerShell as Administrator:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/mdragusm/espanso-sync-template/main/setup.ps1 | iex
```

Both scripts will ask for your GitHub username and repo name during setup. That's the only thing you need to know.

---

## Daily use

### Opening the snippet manager
- **Linux:** run `espanso-manager` in a terminal
- **Windows:** double-click `Espanso Manager` on the desktop

### Syncing manually
```bash
# Linux
espanso-sync

# Windows
cd ~/dotfiles
git add *.yml
git commit -m "update snippets"
git push
```

---

## How it works

- Your snippets live in `~/dotfiles` and sync via GitHub
- A symlink points espanso to that folder instead of its own config folder
- On boot, a systemd service (Linux) or Task Scheduler job (Windows) pulls the latest version automatically
- The manager app always pulls before pushing so it stays in sync across PCs

---

## Snippet format

```yaml
matches:
- trigger: triggerword
  replace: the text you want
- trigger: "@email"
  replace: you@example.com
```

- No quotes needed unless the trigger starts with a special character like `@`
- Triggers are case sensitive
- Use the manager app to add, edit, delete, and organize snippets into groups

---

## Compatibility

- **Linux:** Debian/Ubuntu based distros (Linux Mint, Ubuntu, Pop!_OS, etc.)
- **Windows:** Windows 10/11 with winget available

---

## Troubleshooting

**Symlink broke (Linux)**
```bash
rm ~/.config/espanso/match/base.yml
ln -s ~/dotfiles/base.yml ~/.config/espanso/match/base.yml
```

**Git push rejected**
```bash
cd ~/dotfiles && git pull
```

**Stray characters when a snippet fires**
Make sure `backend: Clipboard` is in:
- Linux: `~/.config/espanso/config/default.yml`
- Windows: `%APPDATA%\espanso\config\default.yml`
