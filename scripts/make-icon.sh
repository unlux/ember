#!/bin/bash
# Regenerates Resources/AppIcon.icns from Resources/icon/AppIcon.svg. Run by
# hand after editing the SVG; the build only copies the committed .icns.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
swift scripts/render-svg.swift Resources/icon/AppIcon.svg "$WORK/1024.png" 1024
SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for size in 16 32 128 256 512; do
    sips -z $size $size "$WORK/1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$WORK/1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
