#!/bin/bash
#
# build.sh — Compiles RedScreen.swift into RedScreen.app
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#
# After building:
#   - Double-click RedScreen.app to run
#   - Drag it to /Applications if you want
#   - Add to Login Items for auto-start
#
# First launch: macOS will say "unidentified developer."
# Right-click → Open to bypass this once. After that it opens normally.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/RedScreen.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "Building RedScreen.app..."

# Create bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile
swiftc "$SCRIPT_DIR/RedScreen.swift" \
    -o "$MACOS_DIR/RedScreen" \
    -framework Cocoa \
    -O

# Write Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RedScreen</string>
    <key>CFBundleDisplayName</key>
    <string>RedScreen</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.redscreen</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>RedScreen</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Generate a simple red circle .icns icon using iconutil
echo "Generating app icon..."
ICONSET_DIR="$CONTENTS/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Create icon PNGs using Python (available on all Macs)
python3 << PYEOF
import struct, zlib, os

def make_red_circle_png(size, path):
    """Generate a PNG of a red filled circle on transparent background."""
    pixels = bytearray()
    center = size / 2.0
    radius = size * 0.4
    for y in range(size):
        pixels.append(0)  # filter byte
        for x in range(size):
            dx = x + 0.5 - center
            dy = y + 0.5 - center
            dist = (dx*dx + dy*dy) ** 0.5
            if dist < radius - 0.5:
                pixels.extend([220, 40, 40, 255])  # solid red
            elif dist < radius + 0.5:
                alpha = int(255 * max(0, min(1, radius + 0.5 - dist)))
                pixels.extend([220, 40, 40, alpha])  # antialiased edge
            else:
                pixels.extend([0, 0, 0, 0])  # transparent

    def make_chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = make_chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    idat = make_chunk(b'IDAT', zlib.compress(bytes(pixels), 9))
    iend = make_chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(header + ihdr + idat + iend)

iconset = "$ICONSET_DIR"
sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    if s <= 512:
        make_red_circle_png(s, os.path.join(iconset, f'icon_{s}x{s}.png'))
    if s <= 1024 and s >= 32:
        half = s // 2
        if half >= 16:
            make_red_circle_png(s, os.path.join(iconset, f'icon_{half}x{half}@2x.png'))
PYEOF

iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$ICONSET_DIR" 2>/dev/null || {
    echo "(Icon generation skipped — app will work without a custom icon)"
}

# Clean up iconset
rm -rf "$ICONSET_DIR"

echo ""
echo "✓ Built: $APP_DIR"
echo ""
echo "To run:    open $APP_DIR"
echo "           (or double-click in Finder)"
echo ""
echo "First launch: right-click → Open to bypass Gatekeeper."
echo "To auto-start: add to System Settings → General → Login Items."
