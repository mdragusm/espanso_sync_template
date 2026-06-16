# Run this on any Windows machine to build a standalone EspansoManager.exe
# No Python install needed on the target machine after building

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       ESPANSO MANAGER BUILDER        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check Python is available
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "✗ Python not found. Install it from python.org first." -ForegroundColor Red
    exit 1
}

Write-Host "▶ Installing build dependencies..." -ForegroundColor Yellow
pip install pyinstaller pyyaml --quiet
Write-Host "  ✓ Done" -ForegroundColor Green

Write-Host ""
Write-Host "▶ Building EspansoManager.exe..." -ForegroundColor Yellow
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
pyinstaller --onefile --windowed --name "EspansoManager" "$ScriptDir\espanso_adder.py" --distpath "$ScriptDir\dist"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           BUILD COMPLETE! ✓          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  EspansoManager.exe is in the 'dist' folder" -ForegroundColor White
    Write-Host "  Copy it anywhere and run it directly — no Python needed" -ForegroundColor White
    Write-Host ""
    # Open the dist folder
    Start-Process explorer "$ScriptDir\dist"
} else {
    Write-Host "✗ Build failed. Check the output above." -ForegroundColor Red
}

Read-Host "Press Enter to exit"
