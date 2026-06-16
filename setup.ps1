# Run as Administrator
Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       ESPANSO SETUP - WINDOWS        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$DOTFILES = "$env:USERPROFILE\dotfiles"
$ESPANSO_MATCH = "$env:APPDATA\espanso\match"
$ESPANSO_CONFIG = "$env:APPDATA\espanso\config"

# ── 0. Developer Mode check ───────────────────────────────────────────────────
$devMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devMode -ne 1) {
    Write-Host "⚠  Developer Mode is not enabled." -ForegroundColor Yellow
    Write-Host "   Symlinks require Developer Mode on Windows." -ForegroundColor Yellow
    Write-Host "   Enable it at: Settings → System → For developers → Developer Mode" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Opening settings now..." -ForegroundColor Yellow
    Start-Process "ms-settings:developers"
    Read-Host "  Press Enter once Developer Mode is enabled"
}

# ── 1. Install dependencies ───────────────────────────────────────────────────
Write-Host "▶ Installing Git..." -ForegroundColor Yellow
winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
Write-Host "  ✓ Git installed" -ForegroundColor Green

Write-Host "▶ Installing Espanso..." -ForegroundColor Yellow
winget install --id Espanso.Espanso -e --silent --accept-source-agreements --accept-package-agreements
Write-Host "  ✓ Espanso installed" -ForegroundColor Green

Write-Host "▶ Installing Python..." -ForegroundColor Yellow
winget install --id Python.Python.3 -e --silent --accept-source-agreements --accept-package-agreements
Write-Host "  ✓ Python installed" -ForegroundColor Green

# Refresh PATH so git/python/pip are available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "▶ Installing PyYAML..." -ForegroundColor Yellow
pip install pyyaml --quiet
Write-Host "  ✓ PyYAML installed" -ForegroundColor Green

# ── 2. GitHub repo ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ GitHub repo setup..." -ForegroundColor Yellow

# If run from inside a cloned repo, detect the remote automatically
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RemoteUrl = ""
if (Test-Path "$ScriptDir\.git") {
    $RemoteUrl = git -C $ScriptDir remote get-url origin 2>$null
}

if ($RemoteUrl) {
    # Extract user/repo from remote URL (handles both https and ssh)
    if ($RemoteUrl -match "[:/]([^/]+)/([^/]+?)(\.git)?$") {
        $GITHUB_USER = $Matches[1]
        $REPO = $Matches[2]
    }
    Write-Host "  Detected repo: $GITHUB_USER/$REPO" -ForegroundColor Gray
    $Confirm = Read-Host "  Use this? [Y/n]"
    if ($Confirm -match "^[Nn]$") { $RemoteUrl = "" }
}

if (-not $RemoteUrl) {
    $GITHUB_USER = Read-Host "  Your GitHub username"
    $REPO = Read-Host "  Repo name (e.g. espanso_sync)"
}

Write-Host "  ✓ Will clone: $GITHUB_USER/$REPO" -ForegroundColor Green

# ── 3. SSH key ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Setting up SSH key..." -ForegroundColor Yellow
if (-not (Test-Path "$env:USERPROFILE\.ssh\id_ed25519")) {
    $email = Read-Host "  Enter your email for the SSH key"
    ssh-keygen -t ed25519 -C $email -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    Write-Host "  ✓ SSH key generated" -ForegroundColor Green
} else {
    Write-Host "  SSH key already exists, skipping" -ForegroundColor Gray
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ACTION REQUIRED: Add this SSH key to your GitHub account   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
Write-Host ""
Write-Host "  Opening GitHub SSH settings in your browser..." -ForegroundColor Yellow
Start-Process "https://github.com/settings/ssh/new"
Write-Host ""
Read-Host "  Press Enter once you've added the key to GitHub"

# ── 4. Test SSH ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Testing GitHub connection..." -ForegroundColor Yellow
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
    Write-Host "  ✓ Connected!" -ForegroundColor Green
} else {
    Write-Host "  ✗ Could not connect to GitHub. Make sure you added the key and try again." -ForegroundColor Red
    exit 1
}

# ── 5. Clone repo ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Cloning repo..." -ForegroundColor Yellow
if (Test-Path "$DOTFILES\.git") {
    Write-Host "  Repo already exists, pulling latest..." -ForegroundColor Gray
    git -C $DOTFILES pull
} else {
    git clone "git@github.com:$GITHUB_USER/$REPO.git" $DOTFILES
}
Write-Host "  ✓ Done" -ForegroundColor Green

# ── 6. Symlinks ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Setting up symlinks..." -ForegroundColor Yellow
if (-not (Test-Path $ESPANSO_MATCH)) { New-Item -ItemType Directory -Path $ESPANSO_MATCH | Out-Null }
Get-ChildItem "$DOTFILES\*.yml" | ForEach-Object {
    $yml = $_.FullName
    $fname = $_.Name
    $link = "$ESPANSO_MATCH\$fname"
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -ne "SymbolicLink") {
            Move-Item $link "$link.bak"
            Write-Host "  Backed up existing $fname" -ForegroundColor Gray
        } else {
            Remove-Item $link -Force
        }
    }
    cmd /c mklink "$link" "$yml" | Out-Null
    Write-Host "  ✓ Symlinked $fname" -ForegroundColor Green
}

# ── 7. Clipboard backend ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Configuring espanso..." -ForegroundColor Yellow
if (-not (Test-Path $ESPANSO_CONFIG)) { New-Item -ItemType Directory -Path $ESPANSO_CONFIG | Out-Null }
$defaultYml = "$ESPANSO_CONFIG\default.yml"
if (-not (Test-Path $defaultYml)) {
    Set-Content $defaultYml "backend: Clipboard"
} elseif (-not (Select-String -Path $defaultYml -Pattern "backend")) {
    Add-Content $defaultYml "`nbackend: Clipboard"
}
Write-Host "  ✓ Clipboard backend set" -ForegroundColor Green

# ── 8. Task Scheduler ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Setting up boot sync..." -ForegroundColor Yellow
git config --global pull.rebase false
$action = New-ScheduledTaskAction -Execute "git" -Argument "-C `"$DOTFILES`" pull"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName "EspansoGitSync" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
Write-Host "  ✓ Task scheduled" -ForegroundColor Green

# ── 9. Desktop shortcut ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "▶ Creating desktop shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Espanso Manager.lnk")
$Shortcut.TargetPath = "pythonw.exe"
$Shortcut.Arguments = "`"$DOTFILES\espanso_adder.py`""
$Shortcut.Save()
Write-Host "  ✓ Shortcut created on desktop" -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           ALL DONE! ✓                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Double-click 'Espanso Manager' on your desktop to manage snippets" -ForegroundColor White
Write-Host "  Espanso will auto-sync from GitHub on every login" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
