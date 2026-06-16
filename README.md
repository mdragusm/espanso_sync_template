# Espanso Sync

Cross-platform espanso snippet manager. Edit once, sync everywhere via GitHub.

## What's in this repo

| File | Purpose |
|------|---------|
| `base.yml` | Your espanso snippets |
| `espanso_adder.py` | GUI app to add, edit, and delete snippets |
| `espanso_setup.sh` | Auto-setup script for Linux |
| `setup.ps1` | Auto-setup script for Windows |
| `create_shortcut.ps1` | Creates desktop shortcut on Windows |

---

## Requirements

The GUI app (`espanso_adder.py`) requires **PyYAML**:

```bash
pip install pyyaml
```

The setup scripts install this automatically.

---

## Setting up on a new PC

### Linux
Open a terminal and run:
```bash
curl -o setup.sh https://raw.githubusercontent.com/mdragusm/espanso_sync/main/espanso_setup.sh && bash setup.sh
```
Follow the prompts. The only manual step is adding the SSH key to GitHub when it asks.

### Windows
Open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/mdragusm/espanso_sync/main/setup.ps1 | iex
```
Follow the prompts. The only manual step is adding the SSH key to GitHub when it opens the browser.

---

## Daily use

### Opening the snippet manager
- **Linux:** run `espanso-manager` in a terminal
- **Windows:** double-click `Espanso Manager` on the desktop

The app lets you add, edit, and delete snippets. It automatically pulls the latest from GitHub, pushes your changes, and restarts espanso when you're done.

### Syncing manually
If you edited any `.yml` file directly and want to push:
```bash
# Linux
espanso-sync

# Windows (in PowerShell)
cd ~/dotfiles
git add *.yml
git commit -m "update snippets"
git push
```

### Getting changes on another PC
Boot the PC — it pulls automatically on login. Or manually:
```bash
cd ~/dotfiles && git pull
```

---

## How it works

```
base.yml in ~/dotfiles  ←──── GitHub repo ────→  base.yml in ~/dotfiles
        ↓                                                  ↓
   symlink                                            symlink
        ↓                                                  ↓
~/.config/espanso/match/base.yml          %APPDATA%\espanso\match\base.yml
        ↓                                                  ↓
     espanso                                            espanso
```

- `base.yml` (and any group `.yml` files) live in `~/dotfiles` and are synced via GitHub
- Symlinks point espanso to those files instead of its own config folder
- On boot, a systemd service (Linux) or Task Scheduler job (Windows) runs `git pull` to get the latest version
- The manager app pulls before pushing so it's always in sync, even right after boot

---

## Snippet format

Snippets in `base.yml` follow this format:
```yaml
matches:
- trigger: triggerword
  replace: the text you want
- trigger: '@pro'
  replace: your@email.com
```

- The GUI app handles quoting automatically — you don't need to worry about special characters
- Triggers are case sensitive
- Espanso detects the trigger as you type and replaces it automatically

---

## Privacy note

Be careful committing personal snippet files (emails, phone numbers, addresses) to a **public** repo. If you have sensitive snippets, either make the repo private or add those `.yml` filenames to `.gitignore`.

---

## Troubleshooting

**Symlink broke (Linux)**
```bash
rm ~/.config/espanso/match/base.yml
ln -s ~/dotfiles/base.yml ~/.config/espanso/match/base.yml
```
The systemd service auto-repairs this on every boot/restart so it fixes itself automatically.

**Git push rejected**
Someone pushed changes you don't have locally. Pull first:
```bash
cd ~/dotfiles && git pull
```
Then try again. Avoid editing `.yml` files directly on GitHub to prevent conflicts.

**Snippets not working after editing**
Espanso needs to restart to pick up changes. The app does this automatically, but if needed:
```bash
# Linux / Windows
espanso restart
```

**Stray characters when a snippet fires**
Make sure `backend: Clipboard` is set in:
- Linux: `~/.config/espanso/config/default.yml`
- Windows: `%APPDATA%\espanso\config\default.yml`
