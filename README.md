# trackpad-volume

macOS menu-bar volume & brightness control via trackpad gestures.
Fn+vertical scroll → volume. Fn+horizontal swipe → brightness.

## For end users (download)

1. Download `trackpad-volume.app` (ask the developer for the zip)
2. Drag to `~/Applications`
3. **Right-click → Open** the first time (ad-hoc signed, Gatekeeper bypass)
4. Grant **Accessibility** permission when prompted
5. Use the menubar icon to toggle **Launch at Login**

## For developers (build from source)

```bash
git clone https://github.com/developer-learner/trackpad-volume.git
cd trackpad-volume
scripts/deploy.sh
```

The script builds, creates `~/Applications/trackpad-volume.app`, and installs a LaunchAgent. Then grant Accessibility as above.

## How it works

A Swift menubar app with a CGEventTap intercepting scroll-wheel events when Fn (🌐) is held:

| Gesture | Action |
|---------|--------|
| Fn + vertical scroll | Volume |
| Fn + horizontal swipe | Brightness |
| Regular scroll (no Fn) | Normal page scrolling |

**Volume:** CoreAudio three-tier fallback (per-channel scalar → main element →
virtual master `'vmvc'`) with NSAppleScript on a background thread as last resort.

**Brightness:** `DisplayServicesGetBrightness`/`SetBrightness` loaded at runtime
via `dlopen` from the dyld shared cache. Works on Apple Silicon (macOS 26+).

## Requirements

macOS 13+, Swift 5.9+ (to build). No Xcode needed.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
