#!/bin/bash

set -e

DOTFILES="$HOME/dotfiles"
ESPANSO_MATCH="$HOME/.config/espanso/match"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       ESPANSO SETUP SCRIPT           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 0. Distro check ───────────────────────────────────────────────────────────
if ! command -v apt &>/dev/null; then
    echo "⚠  This script is designed for Debian/Ubuntu (apt)."
    echo "   On other distros, install these manually before continuing:"
    echo "     git, python3-tk, python3-pip, espanso"
    echo ""
    read -p "Continue anyway? [y/N] " CONTINUE
    [[ "$CONTINUE" =~ ^[Yy]$ ]] || exit 0
fi

# ── 1. Dependencies ───────────────────────────────────────────────────────────
echo "▶ Installing dependencies..."
sudo apt install -y git python3-tk python3-pip espanso 2>/dev/null || true
pip3 install pyyaml --break-system-packages -q 2>/dev/null || pip3 install pyyaml -q || true
echo "  ✓ Done"

# ── 2. GitHub repo ────────────────────────────────────────────────────────────
echo ""
echo "▶ GitHub repo setup..."

# If this script is being run from inside a cloned repo, use that remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_URL=""
if [ -d "$SCRIPT_DIR/.git" ]; then
    REMOTE_URL=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
fi

if [ -n "$REMOTE_URL" ]; then
    # Extract user/repo from remote URL (handles both https and ssh)
    GITHUB_USER=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+)/([^/]+)(\.git)?$|\1|')
    REPO=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+)/([^/]+)(\.git)?$|\2|' | sed 's/\.git$//')
    echo "  Detected repo: $GITHUB_USER/$REPO"
    read -p "  Use this? [Y/n] " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        REMOTE_URL=""
    fi
fi

if [ -z "$REMOTE_URL" ]; then
    read -p "  Your GitHub username: " GITHUB_USER
    read -p "  Repo name (e.g. espanso_sync): " REPO
fi

echo "  ✓ Will clone: $GITHUB_USER/$REPO"

# ── 3. SSH key ────────────────────────────────────────────────────────────────
echo ""
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "▶ Generating SSH key..."
    read -p "  Enter your email for the SSH key: " EMAIL
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "  ✓ SSH key generated"
else
    echo "▶ SSH key already exists, skipping generation"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ACTION REQUIRED: Add this SSH key to your GitHub account   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
cat "$HOME/.ssh/id_ed25519.pub"
echo ""
echo "  1. Go to: https://github.com/settings/ssh/new"
echo "  2. Paste the key above and save it"
echo ""
read -p "Press Enter once you've added the key to GitHub..."

# ── 4. Test SSH ───────────────────────────────────────────────────────────────
echo ""
echo "▶ Testing GitHub connection..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" && echo "  ✓ Connected!" || {
    echo "  ✗ Could not connect to GitHub. Make sure you added the key and try again."
    exit 1
}

# ── 5. Clone repo ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Cloning repo..."
if [ -d "$DOTFILES/.git" ]; then
    echo "  Repo already exists, pulling latest..."
    git -C "$DOTFILES" pull
else
    git clone git@github.com:$GITHUB_USER/$REPO.git "$DOTFILES"
fi
echo "  ✓ Done"

# ── 6. Symlink ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Setting up symlinks..."
mkdir -p "$ESPANSO_MATCH"
for yml in "$DOTFILES"/*.yml; do
    fname=$(basename "$yml")
    link="$ESPANSO_MATCH/$fname"
    if [ -f "$link" ] && [ ! -L "$link" ]; then
        mv "$link" "$link.bak"
        echo "  Backed up existing $fname to $fname.bak"
    fi
    ln -sf "$yml" "$link"
    echo "  ✓ Symlinked $fname"
done

# ── 7. Systemd service ────────────────────────────────────────────────────────
echo ""
echo "▶ Setting up systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/espanso.service" << SERVICE
[Unit]
Description=Espanso with GitHub sync
After=network-online.target

[Service]
Type=forking
ExecStartPre=/bin/sh -c '/usr/bin/git -C $DOTFILES pull || true'
ExecStart=/usr/bin/espanso start --unmanaged
Restart=on-failure

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload
systemctl --user enable espanso.service
systemctl --user start espanso.service
echo "  ✓ Service enabled and started"

# ── 8. Git config ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Configuring git..."
git config --global pull.rebase false
echo "  ✓ Done"

# ── 9. Aliases ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Adding aliases..."
BASHRC="$HOME/.bashrc"
grep -q "espanso-sync" "$BASHRC" || echo 'alias espanso-sync="cd ~/dotfiles && git add *.yml && git commit -m \"update snippets\" && git push && cd -"' >> "$BASHRC"
grep -q "espanso-add" "$BASHRC" || echo 'alias espanso-add="python3 ~/dotfiles/espanso_adder.py"' >> "$BASHRC"
echo "  ✓ Done"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║           ALL DONE! ✓                ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Open a new terminal, then run 'espanso-add' to open the snippet manager"
echo "  Espanso will auto-sync from GitHub on every boot"
echo ""
