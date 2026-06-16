# Espanso Sync

Cross-platform espanso snippet manager. Edit once, sync everywhere via GitHub.

## What's in this repo

| File | Purpose |
|------|---------|
| `base.yml` | Your espanso snippets |
| `espanso_adder.py` | GUI app to add, edit, and delete snippets |
| `espanso_setup.sh` | Auto-setup script for Linux |
| `setup.ps1` | Auto-setup script for Windows |
| `requirements.txt` | Python dependencies (`pyyaml`) |

---

## Getting started

### 1. Fork or use this template

Click **"Use this template"** or **"Fork"** on GitHub to create your own copy of this repo.

### 2. Run the setup script

The script will detect your repo automatically if you clone it first, or ask for your GitHub username and repo name.

**Linux (Debian/Ubuntu):**
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git ~/dotfiles
bash ~/dotfiles/espanso_setup.sh
```

**Windows** (open PowerShell as Administrator):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git $env:USERPROFILE\dotfiles_setup
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup.ps1 | iex
```

> **Windows users:** Symlinks require [Developer Mode](ms-settings:developers) to be enabled. The script will check and prompt you if it isn't.

Follow the prompts. The only manual step is adding the SSH key to GitHub when asked.

---

## Daily use

### Opening the snippet manager
- **Linux:** run `espanso-add` in a terminal
- **Windows:** double-click `Espanso Manager` on the desktop

The app lets you add, edit, and delete snippets. It automatically pulls the latest from GitHub, pushes your changes, and restarts espanso when you're done.

### Syncing manually
If you edited a `.yml` file directly:
```bash
# Linux
espanso-sync

# Windows (PowerShell)
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
*.yml in ~/dotfiles  ←──── GitHub repo ────→  *.yml in ~/dotfiles
        ↓                                               ↓
   symlinks                                         symlinks
        ↓                                               ↓
~/.config/espanso/match/              %APPDATA%\espanso\match\
        ↓                                               ↓
     espanso                                         espanso
```

- All `.yml` files live in `~/dotfiles` and are synced via GitHub
- Symlinks point espanso to those files instead of its own config folder
- On boot, a systemd service (Linux) or Task Scheduler job (Windows) runs `git pull`
- The manager app pulls before pushing so it's always in sync

---

## Snippet format

```yaml
matches:
- trigger: ":name"
  replace: Your Name
- trigger: "@email"
  replace: your@email.com
```

- Triggers are case sensitive
- The GUI handles special characters automatically — no manual quoting needed
- Espanso detects the trigger as you type and replaces it inline

---

## Troubleshooting

**Manager won't launch**
```bash
pip install pyyaml --break-system-packages  # Linux
pip install pyyaml                           # Windows
```

**Symlink broke (Linux)**
```bash
ln -sf ~/dotfiles/base.yml ~/.config/espanso/match/base.yml
```
The systemd service auto-repairs this on every boot.

**Git push rejected**
Pull first, then push:
```bash
cd ~/dotfiles && git pull && git push
```

**Snippets not working after editing**
```bash
espanso restart
```

**Stray characters when a snippet fires**
Make sure `backend: Clipboard` is set in:
- Linux: `~/.config/espanso/config/default.yml`
- Windows: `%APPDATA%\espanso\config\default.yml`
