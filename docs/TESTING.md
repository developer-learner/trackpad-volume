# TESTING.md — Testing Strategy

> Strategy and conventions, not results.
> This project has no automated test suite — CoreAudio and DisplayServices
> are hardware-bound APIs that cannot be unit tested without real devices.

---

## Philosophy

- No automated tests — hardware APIs (CoreAudio, DisplayServices) can't be mocked meaningfully
- Every change is verified by running the tool and testing on real hardware
- CI is not applicable — no test runner, no coverage

---

## Manual Test Checklist

Run the built binary and verify each scenario:

### Volume

| Scenario | Steps | Expected |
|----------|-------|----------|
| Headphones | Plug in headphones, Fn+vertical scroll | Volume changes, left/right channels balance |
| Built-in speakers | Disconnect headphones, Fn+scroll | Volume changes (virtual master `'vmvc'` path) |
| External DAC | Connect USB DAC, Fn+scroll | Volume changes (main element path) |
| Mute edge | Scroll down repeatedly | Volume stays at 0, no overflow |
| Max edge | Scroll up repeatedly | Volume stays at 1, no overflow |
| No Fn | Scroll without holding Fn | Normal page scrolling, no volume change |

### Brightness

| Scenario | Steps | Expected |
|----------|-------|----------|
| Normal | Fn+horizontal swipe | Brightness changes smoothly |
| Internal display only | On MacBook with no external monitor | Brightness adjusts |
| External monitor | Connect external display | Brightness adjusts on built-in display (only one CGMainDisplayID) |
| Min edge | Swipe left repeatedly | Brightness stays at 0 |
| Max edge | Swipe right repeatedly | Brightness stays at 1 |

### Launch at Login

| Scenario | Steps | Expected |
|----------|-------|----------|
| SMAppService toggle | Click menu → "Launch at Login" | App appears in System Settings → Login Items |
| Toggle off | Click again | Removed from Login Items |
| LaunchAgent | `scripts/deploy.sh` | `launchctl list` shows running instance |

### Accessibility

| Scenario | Steps | Expected |
|----------|-------|----------|
| First launch | Open `.app` | System dialog for Accessibility permission |
| Rebuild | `swift build && deploy` | Re-grant needed (ad-hoc signing changes identity) |

---

## What We Don't Test

- CoreAudio framework internals (Apple tests those)
- DisplayServices internals (private framework, tested by Apple)
- CGEventTap (system API, tested by Apple)
- NSStatusItem / NSMenu rendering (AppKit, tested by Apple)
