#!/bin/bash

set -e

GITHUB_USER="mdragusm"
REPO="espanso_sync"
DOTFILES="$HOME/dotfiles"
ESPANSO_MATCH="$HOME/.config/espanso/match"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       ESPANSO SETUP SCRIPT           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Dependencies ───────────────────────────────────────────────────────────
echo "▶ Installing dependencies..."
sudo apt install -y git python3-tk python3-pip espanso 2>/dev/null || true
pip3 install pyyaml --break-system-packages -q 2>/dev/null || pip3 install pyyaml -q || true
echo "  ✓ Done"

# ── 2. SSH key ────────────────────────────────────────────────────────────────
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo ""
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

# ── 3. Test SSH ───────────────────────────────────────────────────────────────
echo ""
echo "▶ Testing GitHub connection..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" && echo "  ✓ Connected!" || {
    echo "  ✗ Could not connect to GitHub. Make sure you added the key and try again."
    exit 1
}

# ── 4. Clone repo ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Cloning repo..."
if [ -d "$DOTFILES/.git" ]; then
    echo "  Repo already exists, pulling latest..."
    git -C "$DOTFILES" pull
else
    git clone git@github.com:$GITHUB_USER/$REPO.git "$DOTFILES"
fi
echo "  ✓ Done"

# ── 5. Symlink ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Setting up symlink..."
mkdir -p "$ESPANSO_MATCH"
if [ -f "$ESPANSO_MATCH/base.yml" ] && [ ! -L "$ESPANSO_MATCH/base.yml" ]; then
    mv "$ESPANSO_MATCH/base.yml" "$ESPANSO_MATCH/base.yml.bak"
    echo "  Backed up existing base.yml to base.yml.bak"
fi
ln -sf "$DOTFILES/base.yml" "$ESPANSO_MATCH/base.yml"
echo "  ✓ Symlink created"

# ── 6. Systemd service ────────────────────────────────────────────────────────
echo ""
echo "▶ Setting up systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/espanso.service" << 'SERVICE'
[Unit]
Description=Espanso with GitHub sync
After=network-online.target

[Service]
Type=forking
ExecStartPre=/bin/sh -c '/usr/bin/git -C /home/PLACEHOLDER/dotfiles pull || true'
ExecStart=/usr/bin/espanso start --unmanaged
Restart=on-failure

[Install]
WantedBy=default.target
SERVICE

# Replace PLACEHOLDER with actual username
sed -i "s/PLACEHOLDER/$USER/g" "$HOME/.config/systemd/user/espanso.service"

systemctl --user daemon-reload
systemctl --user enable espanso.service
systemctl --user start espanso.service
echo "  ✓ Service enabled and started"

# ── 7. Git config ─────────────────────────────────────────────────────────────
echo ""
echo "▶ Configuring git..."
git config --global pull.rebase false
echo "  ✓ Done"

# ── 8. Aliases ────────────────────────────────────────────────────────────────
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
echo "  Run 'espanso-add' to open the snippet manager (new terminal)"
echo "  Espanso will auto-sync from GitHub on every boot"
echo ""
