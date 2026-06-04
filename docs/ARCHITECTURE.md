# Architecture — System Design

> Living document. Update when structure changes.
> LLMs read this to understand how the system fits together.

---

## System Overview

Single-file Swift CLI (`main.swift`) that installs a CGEventTap to intercept scroll-wheel events. Fn+vertical scroll controls volume via CoreAudio (three-tier fallback) or NSAppleScript fallback; Fn+horizontal scroll controls display brightness via DisplayServices (dlopen'd from dyld shared cache). No GUI, no daemon, no background services — runs as a terminal process or LaunchAgent.

---

## Key Flows

### Scroll → Volume / Brightness

1. CGEventTap receives scroll-wheel event
2. Callback checks `flags` for Fn (`.maskSecondaryFn`) — if absent, passes event through unchanged
3. Horizontal vs vertical: `abs(axis2)` vs `abs(axis1)` — whichever dominates routes to its mode (brightness or volume respectively)
4. Each mode has its own scroll accumulator (`scrollAccumVolume`, `scrollAccumBrightness`)
5. Mode-specific delta added to its accumulator; `Int(accumulator / pxPerStepVolume)` clamped to [-1, 1] for volume, `Int(accumulator / pxPerStepBrightness)` clamped to [-5, 5] for brightness
6. Mode-specific function called (`changeVolume` / `changeBrightness`) with signed step count
7. Accumulator decremented by `steps * pxPerStep` (keeps each bounded)
8. Event consumed (return nil) → scroll is suppressed, page does not move

### Volume Change — Three-Tier Fallback

All tiers use `changeVolume(deltaSteps:)`, same `delta = Float32(deltaSteps) * 0.16` (+/- 16% per step, ±1 step max per event due to cap). Multiplier is `deltaSteps * 16` for NSAppleScript fallback (0–100 osascript scale).

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

**Fallback — NSAppleScript**
```applescript
set volume output volume ((output volume of (get volume settings)) + deltaSteps * 16)
```
If all CoreAudio paths fail. Runs on global async queue via `DispatchQueue.global().async` to avoid blocking the event-tap thread (which would trigger a tap timeout). Uses NSAppleScript (in-process, no subprocess). Note: on macOS 26 (Tahoe), CoreAudio scalar writes DO change the system volume (verified), so the fallback is only hit on unusual hardware configurations.

---

## Brightness Control

Display brightness is controlled through `DisplayServicesGetBrightness`/`DisplayServicesSetBrightness` loaded at runtime via `dlopen` from the dyld shared cache. Uses the same `Float` scaling (0.0–1.0) as volume, with `delta = Float(deltaSteps) * 0.02`.

### Loading Approach

```swift
guard let handle = dlopen(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
    RTLD_LAZY
) else { return (nil, nil) }
let get = dlsym(handle, "DisplayServicesGetBrightness")
let set = dlsym(handle, "DisplayServicesSetBrightness")
```

On macOS 26+ (Tahoe), `DisplayServices.framework` binary is **missing from disk** — the symlink `Versions/Current/DisplayServices` points to a non-existent binary. However, the symbols are available through the dyld shared cache, and `dlopen` succeeds. `RTLD_DEFAULT` (used by `dlsym` without `dlopen`) would fail because the framework isn't pre-loaded.

### Why not IOKit

`AppleLMUController` service does not exist on Apple Silicon Macs. `IODisplayConnect` also absent. `AppleARMBacklight` in IORegistry has no user-client for programmatic writes — IORegistry writes are ignored. The `brightness` CLI (nriley) returns `kIOReturnUnsupported` on this hardware.

### Target Display

Controls the main display (`CGMainDisplayID()`, always returns 1 on single-display MacBooks). Does not enumerate or select external displays. Each scroll event: `deltaSteps * 0.02` (2% per step), ±5 steps max = ±10% per event. `pxPerStepBrightness = 11.0` (~9% faster scroll-to-step ratio than original 12.0). Activated by Fn+horizontal two-finger swipe (axis2 dominates axis1).

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
| `pxPerStepVolume` | 48.0 | Scroll pixels per volume step — higher = less sensitive |
| `pxPerStepBrightness` | 11.0 | Scroll pixels per brightness step — slightly faster than original 12.0 |
| `kVirtualMasterVolume` | `0x766D7663` ('vmvc') | FourCharCode for virtual master volume property |
| `volumeStepScale` | 0.16 | Float delta per volume step (≈16% of full scale) |
| `brightnessStepScale` | 0.02 | Float delta per brightness step (2% of full scale) |
| `deltaMultiplier` | 16 | Multiplier for osascript fallback step size (0–100 scale) |

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
steps = Int(scrollAccum / pxPerStepVolume), clamped [-1, 1] for volume; [-5, 5] for brightness
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
scrollAccum -= steps * pxPerStep{Volume,Brightness}
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
- **Threading:** NSAppleScript fallback runs on a global background queue (`DispatchQueue.global().async`). This is critical — if NSAppleScript ran on the event-tap thread, it could trigger a tap timeout under fast scrolling.
- **Accessibility permission:** Verified on macOS 14.x. The input-monitoring boundary is the surface Apple moves most — re-check on every major OS bump.
- **Brightness uses DisplayServices via dyld shared cache.** Framework binary may be missing on macOS 26+ (Tahoe) but `dlopen` succeeds. Silently no-ops if `dlopen` or `dlsym` fails (e.g., future macOS version removes the symbols from shared cache).
- **Modal conflicts:** Fn+horizontal two-finger swipe has no system-wide binding on macOS. Unlike Fn+⌥ (which could conflict with some apps), the axis-based routing is conflict-free. Diagonal scrolls are dominated by whichever axis has larger magnitude.
