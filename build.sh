#!/bin/bash
# Run this on any Linux machine to build a standalone EspansoManager binary

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       ESPANSO MANAGER BUILDER        ║"
echo "╚══════════════════════════════════════╝"
echo ""

if ! command -v python3 &>/dev/null; then
    echo "✗ Python3 not found. Install it first."
    exit 1
fi

echo "▶ Installing build dependencies..."
pip3 install pyinstaller pyyaml --break-system-packages -q 2>/dev/null || pip3 install pyinstaller pyyaml -q
echo "  ✓ Done"

echo ""
echo "▶ Building EspansoManager binary..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pyinstaller --onefile --windowed --name "EspansoManager" "$SCRIPT_DIR/espanso_adder.py" --distpath "$SCRIPT_DIR/dist"

if [ $? -eq 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║           BUILD COMPLETE! ✓          ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "  EspansoManager binary is in the 'dist' folder"
    echo "  Copy it anywhere and run it directly — no Python needed"
    echo ""
else
    echo "✗ Build failed. Check the output above."
    exit 1
fi
