# RedScreen

A tiny, fully transparent macOS **menu bar utility** that turns your display into red-on-black darkroom mode.

## What it does

Zeroes out the green and blue display channels and inverts the red channel, so white backgrounds become black and dark content glows red. This is the same technique f.lux uses for its "Darkroom" mode.

### Why red?

- Red light has the least impact on dark adaptation (night vision)
- A red-only screen emits dramatically less total light
- Eliminates visual "noise" of colors, reducing distraction
- Standard approach in astronomy, military, and darkroom contexts

## Installation

```bash
# Build the .app bundle (requires Xcode command line tools)
chmod +x build.sh
./build.sh
```

This produces `RedScreen.app` — a standard double-clickable macOS app. You can:

- **Double-click** it in Finder to run
- Drag it to `/Applications`
- Add it to **System Settings → General → Login Items** for auto-start

On first launch, macOS will say "unidentified developer" since it's not signed. **Right-click → Open** to bypass this once; after that it opens normally.

You can also skip the build and run the source directly: `swift RedScreen.swift`

## Usage

A small circle icon appears in your menu bar. Click it to access:

- **Enable Darkroom** — toggle the red-on-black effect on and off
- **About RedScreen** — info about the app
- **Quit RedScreen** — restores normal display and exits

When active, the menu bar icon turns into a solid red dot. When off, it's a circle outline that adapts to light/dark mode.

Use your Mac's built-in brightness controls (keyboard keys) to adjust how much light the screen emits.

## Tips

- **Lower your display brightness** for comfortable night use — the darkroom effect combined with minimum hardware brightness is very easy on the eyes.
- **Add to Login Items** (System Settings → General → Login Items) to launch at startup.

## How it works

The app uses `CGSetDisplayTransferByTable` to set explicit 256-entry lookup tables for each RGB channel:

- **Red channel**: A reversed (inverted) linear ramp — input 0 (black pixels) maps to full red output, input 255 (white pixels) maps to 0 (black output).
- **Green/Blue channels**: All zeros — these colors are never emitted.

Because macOS ColorSync periodically resets custom gamma ramps, the app re-applies the tables every second via a dispatch timer and also listens for `CGDisplayReconfigurationCallback` to catch sleep/wake and display changes.

When you quit or disable, it calls `CGDisplayRestoreColorSyncSettings()` to restore normal colors.

## No permissions needed

Uses public Core Graphics APIs — no root, no accessibility permissions, no entitlements, no code signing.

## License

Public domain. Do whatever you like with it.
