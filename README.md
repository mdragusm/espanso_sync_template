# Espanso Sync Template

Cross-platform espanso snippet manager. Edit once, sync everywhere via GitHub.

## First time setup

1. Create a **private GitHub repo** (e.g. `espanso_sync`)
2. Push these files to it
3. Run the setup script on each PC

## Setting up on a new PC

### Linux
```bash
curl -o setup.sh https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/espanso_setup.sh && bash setup.sh
```

### Windows
Open PowerShell as Administrator:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup.ps1 | iex
```

Both scripts will ask for your GitHub username and repo name during setup.

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

- `base.yml` lives in `~/dotfiles` and is synced via GitHub
- A symlink points espanso to that file instead of its own config folder
- On boot, a systemd service (Linux) or Task Scheduler job (Windows) runs `git pull`
- The manager app pulls before pushing so it's always in sync

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
