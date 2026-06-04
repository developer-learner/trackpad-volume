# Architecture — System Design

> Living document. Update when structure changes.
> LLMs read this to understand how the system fits together.

---

## System Overview

Single-file Swift CLI (`main.swift`) that installs a CGEventTap to intercept scroll-wheel events. Fn+scroll controls volume via CoreAudio (instant) or NSAppleScript fallback; Fn+⌥+scroll controls display brightness via IOKit (`AppleLMUController`). No GUI, no daemon, no background services — runs as a terminal process or LaunchAgent.

---

## Key Flows

### Scroll → Volume / Brightness

1. CGEventTap receives scroll-wheel event
2. Callback checks `flags` for Fn (`.maskSecondaryFn`) — if absent, passes event through unchanged
3. If `flags` also contains `.maskAlternate` (⌥) → **brightness** mode, else **volume** mode
4. Each mode has its own scroll accumulator (`scrollAccumVolume`, `scrollAccumBrightness`)
5. Mode-specific delta added to its accumulator; `Int(accumulator / pxPerStep)` clamped to [-5, 5] → 0–5 steps
6. Mode-specific function called (`changeVolume` / `changeBrightness`) with signed step count
7. Accumulator decremented by `steps * pxPerStep` (keeps each bounded)
8. Event consumed (return nil) → scroll is suppressed, page does not move

### Volume Change — Three-Tier Fallback

All tiers use `changeVolume(deltaSteps:)`, same `delta = Float32(deltaSteps) * 0.02` (+/- 2% per step, +/- 10% max per event).

**Tier 1 — Per-Channel Scalar (headphones, instant)**
```
selector: kAudioDevicePropertyVolumeScalar
element: 1 (left channel)
scope:   kAudioDevicePropertyScopeOutput
```
If read succeeds, writes same scalar to element 1 + element 2 (stereo).
Typical latency: <1ms.

**Tier 2 — Main Element Scalar**
```
selector: kAudioDevicePropertyVolumeScalar
element: kAudioObjectPropertyElementMain
scope:   kAudioDevicePropertyScopeOutput
```
If tier 1 fails (device doesn't expose per-channel scalar). Monophonic — no stereo pair write.

**Tier 3 — Virtual Master Volume (MacBook speakers)**
```
selector: 'vmvc' (= 0x766D7663)
element: kAudioObjectPropertyElementMain
scope:   kAudioDevicePropertyScopeOutput
```
If tier 1 + 2 fail (aggregate devices, built-in speakers). Reads/writes the system virtual master. Slightly more latency under rapid scrolling than tier 1.

> **Why `'vmvc'` is manually defined:** This selector was historically `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` in Apple's headers, deprecated in 10.12 and **removed entirely from modern SDKs**. The `AudioHardwareService` wrapper API was also removed. We define the FourCharCode constant manually (`private let kVirtualMasterVolume: AudioObjectPropertySelector = 0x766D7663`) because the selector itself still resolves through `AudioObjectSetPropertyData` — the FourCharCode is the stable contract, the header symbol name is cosmetic. Do not delete or chase the missing SDK symbol.

**Fallback — NSAppleScript (degraded-only)**
```applescript
set volume output volume ((output volume of (get volume settings)) + deltaSteps * 15)
```
If all CoreAudio paths fail. Runs on global async queue via NSAppleScript (in-process, no subprocess). Used by <1% of calls in practice.

> ⚠️ **Degraded mode.** `set volume` operates on integer 0–100 scale, so the `0.02` fractional-accumulation feel collapses to 1% granularity. If any device lands here regularly, **investigate why tiers 1–3 failed** — do not accept this as steady state. This is a last-resort don't-be-dead path.

---

## Brightness Control

Display brightness is controlled through IOKit's `AppleLMUController` service. Unlike the volume path (which has a three-tier fallback), brightness has a single direct path.

### IOKit AppleLMUController API

```
Methods (scalar):
  0  getBrightnessRange  → outputs [min, max]
  1  getBrightness       → output current value
  2  setBrightness       → input new value
```

The range is hardware-dependent (typically 0–1000 or 0–65535). `changeBrightness` reads range + current, applies `delta = deltaSteps * 0.02` (same scaling as volume), clamps to [0, 1], converts back to hardware units, and writes.

### No Fallback

If `AppleLMUController` is unavailable (e.g., external display, desktop Mac), the brightness call silently returns without change. No osascript fallback exists — brightness has no scriptable Apple Events equivalent.

---

## Device Management

### Output Device Caching

On startup, `kAudioHardwarePropertyDefaultOutputDevice` is read once into `cachedDeviceID`. A property listener (`deviceListenerCallback`) is registered on `kAudioHardwarePropertyDefaultOutputDevice` to update the cache whenever the user switches output (e.g., plugs/unplugs headphones). This avoids querying the device ID on every scroll.

### Property Listener

```swift
AudioObjectAddPropertyListener(
    AudioObjectID(kAudioObjectSystemObject),
    &addr,
    deviceListenerCallback,
    nil
)
```

Fires on output device change. Reads new device ID from the same property and stores it in `cachedDeviceID`.

---

## Event Tap

### Setup

```
tap:      .cgSessionEventTap
place:    .headInsertEventTap
mask:     scrollWheel only
```

`.cgSessionEventTap` requires **Accessibility** permission (AX API), not Input Monitoring. The app checks `AXIsProcessTrustedWithOptions` at startup and exits with a prompt if not granted.

### Tap-Enable on Timeout

On `.tapDisabledByTimeout` or `.tapDisabledByUserInput`, the callback re-enables the tap. This handles macOS's automatic tap-disable after certain events (fast scroll spam, etc.).

---

## Configuration

| Constant | Value | Purpose |
|----------|-------|---------|
| `pxPerStep` | 12.0 | Scroll pixels per step — higher = less sensitive |
| `gateVolume` | `.maskSecondaryFn` | Modifier for volume scroll (Fn / 🌐) |
| `gateBrightness` | `.maskSecondaryFn` + `.maskAlternate` | Modifier for brightness scroll (Fn+⌥) |
| `kVirtualMasterVolume` | `0x766D7663` ('vmvc') | FourCharCode for virtual master volume property |
| `deltaMultiplier` | 15 | Multiplier for osascript fallback step size |

---

## Build & Deploy

### Build
```bash
swift build -c release
```
Binary at `.build/release/trackpad-volume`. No Xcode project needed — pure SPM.

### LaunchAgent (auto-start)
1. Copy binary: `cp .build/release/trackpad-volume ~/Applications/`
2. Create `~/Library/LaunchAgents/com.user.trackpad-volume.plist`
3. `launchctl load ~/Library/LaunchAgents/com.user.trackpad-volume.plist`

---

## Event Flow Diagram

```
CGEvent (scroll wheel)
  │
  ▼
eventCallback()
  │
  ├─ Fn held? ── No ──► pass through (return event)
  │
  Yes
  │
  ▼
scrollAccum += delta
  │
  ▼
steps = Int(scrollAccum / pxPerStep), clamped [-5, 5]
  │
  ├─ steps == 0? ── Yes ──► wait for next event
  │
  No
  │
  ▼
changeVolume(deltaSteps: steps)
  │
  ├─ Tier 1 (per-channel scalar) ── success ──► write element 1 + 2 ──► return
  ├─ Tier 2 (main element) ── success ──► write element main ──► return
  ├─ Tier 3 (virtual master) ── success ──► write 'vmvc' ──► return
  └─ Fallback (NSAppleScript) ──► async exec ──► return
  │
  ▼
scrollAccum -= steps * pxPerStep
  │
  ▼
print log line
  │
  ▼
return nil (event consumed)
```

---

## Known Constraints

- **Single output device.** Only controls the system default output device. Does not target specific apps or audio sessions.
- **Fn modifier is hardcoded** to `.maskSecondaryFn`. Cannot be remapped at runtime without recompiling.
- **Virtual master volume** (`'vmvc'`) was deprecated in macOS 10.12 but continues to work on modern macOS (tested on 14.x+).
- **No input monitoring permission needed** — `.cgSessionEventTap` uses Accessibility API only.
- **Threading:** NSAppleScript fallback runs on a global background queue. Not an issue because it's reached only when CoreAudio paths fail.
- **Accessibility permission:** Verified on macOS 14.x. The input-monitoring boundary is the surface Apple moves most — re-check on every major OS bump.
- **Brightness requires `AppleLMUController`.** Only available on Mac laptops with built-in backlight. Desktop Macs and external displays silently no-op.
- **Fn+⌥ conflicts:** Option (⌥) + scroll is also used by some macOS shortcuts. In practice, the Fn requirement disambiguates, but worth verifying on each OS bump.
