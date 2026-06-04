# trackpad-volume

macOS menu-bar-less volume & brightness control via trackpad gestures.
Fn+vertical scroll → volume. Fn+horizontal swipe → brightness.

## Usage

```bash
swift build -c release
./.build/release/trackpad-volume
```

Requires **Accessibility** permission (System Settings → Privacy → Accessibility).
Tapping ^C to quit.

## How it works

A single-file Swift CLI that installs a CGEventTap intercepting scroll-wheel
events when the Fn (🌐) key is held:

| Gesture | Action |
|---------|--------|
| Fn + vertical scroll | Volume |
| Fn + horizontal swipe | Brightness |
| Regular scroll (no Fn) | Normal page scrolling |

**Volume:** CoreAudio three-tier fallback (per-channel scalar → main element →
virtual master `'vmvc'`) with NSAppleScript on a background thread as last resort.

**Brightness:** `DisplayServicesGetBrightness`/`SetBrightness` loaded at runtime
via `dlopen` from the dyld shared cache. Works on Apple Silicon (macOS 26+).

## Build

Requires Swift 5.9+ and macOS 13+. Pure SPM, no Xcode project:

```bash
swift build -c release
```

Binary at `.build/release/trackpad-volume`.

## Deploy as LaunchAgent

```bash
cp .build/release/trackpad-volume ~/Applications/
# create ~/Library/LaunchAgents/com.user.trackpad-volume.plist
launchctl load ~/Library/LaunchAgents/com.user.trackpad-volume.plist
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full system design:
three-tier volume fallback, event flow diagram, brightness loading approach,
device management, and known constraints.
