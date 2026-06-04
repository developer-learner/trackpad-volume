# CLAUDE.md — Master LLM Context File

> This file is automatically read by OpenCode and Claude Code at session start.
> Keep it current. Every correction you make to the LLM should be recorded here
> so the mistake never happens again.

---

## Project Overview

**Name:** trackpad-volume
**What it does:** macOS menu-bar-less volume & brightness control via Fn/trackpad gestures. Fn+vertical scroll → volume (CoreAudio three-tier fallback), Fn+horizontal scroll → brightness (DisplayServices via dyld shared cache). Built as a Swift CLI with CGEventTap.
**Status:** In Development

---

## Tech Stack

```
Language:     Swift 5.9+
Framework:    CoreAudio, ApplicationServices (CGEventTap), DisplayServices (brightness, dlopen'd from dyld shared cache)
Build:        Swift Package Manager
Deploy:       LaunchAgent (launchctl)
```

---

## Project Structure

```
trackpad-volume/
├── Sources/trackpad-volume/main.swift   # single-file app
├── docs/                                # architecture, decisions, product
├── tasks/                               # current work + backlog
├── scripts/                             # dev utilities
├── AGENTS.md                            # this file (read at session start)
├── CONVENTIONS.md                       # code style rules
├── opencode.json                        # opencode project config
└── Package.swift                        # SPM manifest
```

---

## Code Conventions

- Single-file Swift CLI — keep it that way unless it grows significantly
- `print()` is fine for CLI output (no logger library available/needed)
- Prefer simple functions, no classes unless state requires it
- **Three-tier CoreAudio volume fallback** — see `docs/ARCHITECTURE.md` for full details:
  1. Per-channel scalar (element 1) — headphones, instant
  2. Main element scalar — monophonic devices
  3. Virtual master volume (`'vmvc'`) — MacBook speakers, slightly more latency under fast scroll
  4. NSAppleScript fallback — in-process, no subprocess
- **Brightness** via `DisplayServicesGetBrightness`/`SetBrightness` loaded with `dlopen` from dyld shared cache (Fn+horizontal swipe). No IOKit framework needed. On macOS 26+ (Tahoe) the framework binary is missing from disk but symbols are in the shared cache — `dlopen` succeeds, `dlsym(RTLD_DEFAULT)` would fail.
- Separate scroll accumulators per mode (`scrollAccumVolume`, `scrollAccumBrightness`)
- `let volDelta = deltaSteps * 16` — multiplier for osascript fallback (line 54)
- Build with `swift build -c release`, binary at `.build/release/trackpad-volume`
- Deploy as LaunchAgent: copy to ~/Applications/ + launchctl load

---

## What NOT To Do

> These are guardrails. Do not override them without explicit human instruction.

**Code guardrails:**
- **Do not add dependencies** without asking first
- **Do not refactor files** unrelated to the current task
- **Do not change the database schema** without explicit instruction
- **Do not remove error handling** to simplify code
- **Do not use `Any` type** — be specific
- **Do not write `TODO` comments** — either implement it or raise it as a task
- **Do not use `time.sleep()`** in production code — use proper async patterns
- **Do not commit secrets** — use `.env` and ensure `.gitignore` covers it

**Doc references (read these before coding):**
- **`docs/ARCHITECTURE.md`** — Three-tier volume fallback, event tap setup, device management. Read this first before touching volume control code.
- **`docs/DECISIONS.md`** — Architectural decision log. Check before suggesting alternatives.

**Operating guardrails (from hard-won failures — see BLUEPRINT.md):**
- **Do not set a thinking model as the active model.** Thinking models leave `content` empty and put output in `reasoning_content`, which breaks parsing. The model must be non-thinking local OR frontier.
- **Do not retry the same failing fix more than twice.** Two strikes → escalate to a frontier model, or halt and leave a note.
- **Do not trust your own "it works" — only passing tests confirm success.** Run `pytest`. The tests are ground truth, not your assessment. Do not mark a task done on self-judgment.
- **Do not proceed past an unreachable LM Studio or a missing service** — halt and report.
- **Do not invent product or architecture decisions to fill an ambiguous spec** — that is the human's job. Halt and ask.
- **Do not run destructive commands** (`rm -rf`, `git push --force`, drop tables, delete files outside the project) — halt and ask.

---

## Current Focus

**Done.** Three-tier CoreAudio volume control (headphones + speakers) + DisplayServices brightness control via Fn+⌥. See `docs/ARCHITECTURE.md` for the full system design. Binary builds with `swift build -c release`.

**Remaining notes:**
- Virtual master volume path has slightly more latency on fast flicks vs. headphone scalar path — known, acceptable
- Delta multiplier for osascript fallback is 16 (16% per step on osascript 0–100 scale)
- Brightness silently no-ops if `dlopen` or `dlsym` fails (e.g., pre-Tahoe macOS without DisplayServices framework, or if the API changes in a future release)

---

## Key Contacts / Roles

| Role | Name |
|------|------|
| Product owner | [NAME] |
| Lead dev | [NAME] |

---

## LLM Correction Log

> When the LLM makes a mistake and you correct it, log it here.
> This is the most valuable section — it prevents repeat mistakes.
> A project 6 months in should have a rich log. That means the system is working.

| Date | Mistake | Guard Added |
|------|---------|-------------|
| 2026-06-02 | Original code had no proactive Accessibility permission check; user was guessing whether Input Monitoring vs. Accessibility was needed | `.cgSessionEventTap` requires **Accessibility** (AX API) permission, not Input Monitoring. Always call `AXIsProcessTrustedWithOptions` at startup and print clear status. Add `.linkedFramework("ApplicationServices")` to Package.swift for the symbol. |
| 2026-06-04 | Used `Process()` for osascript fallback — user reported lag from fork/exec overhead | Replace with `NSAppleScript` (in-process AppleScript execution). Subprocess spawning adds 50-200ms latency. |
| 2026-06-04 | Tried `kAudioHardwareServiceDeviceProperty_VirtualMasterVolume` symbol directly — not available in Swift scope | Define the FourCharCode manually: `private let kVirtualMasterVolume: AudioObjectPropertySelector = 0x766D7663` ('vmvc'). |
| 2026-06-04 | Virtual master volume read/write works but has slightly more latency than per-channel scalar under fast scroll | This is expected — virtual master goes through system audio processing. Not a bug. Documented in ARCHITECTURE.md. |
| 2026-06-04 | `AGENTS.md` had stale Current Focus still referencing the original `deltaSteps * 12 → 25` change | Keep `Current Focus` in sync with actual project state. Point to docs/ for detailed architecture. |
| 2026-06-04 | Brightness was not implemented | Added DisplayServices-based brightness via `dlopen` from dyld shared cache. Fn+⌥+scroll. `DisplayServicesGetBrightness`/`SetBrightness` on `CGMainDisplayID()`. No IOKit — `AppleLMUController` doesn't exist on Apple Silicon. |
| 2026-06-04 | Used `.maskAlternate` for brightness modifier — must verify no macOS Fn+⌥+scroll conflicts | Option+scroll is used by some system shortcuts, but the Fn requirement disambiguates. Documented in Known Constraints. |
| 2026-06-04 | Used `dlsym(RTLD_DEFAULT, ...)` for DisplayServices symbols — failed on macOS 26 (Tahoe) where framework binary is missing from disk, even though symbols are in dyld shared cache | Use `dlopen("...DisplayServices", RTLD_LAZY)` first, then `dlsym(handle, ...)`. `RTLD_DEFAULT` only searches already-loaded libraries. On Tahoe the framework must be loaded from shared cache. |
| 2026-06-04 | Claimed CoreAudio writes return `noErr` but don't change system volume on Tahoe — WRONG. Verified: CoreAudio `'vmvc'` and element-main writes DO change system volume (osascript readback confirms). Moved NSAppleScript off event-tap thread to fix tap-timeout risk. | CoreAudio scalar writes work on Tahoe. Do not assume breakage without testing write + osascript readback. Always move fallback work off the event-tap thread with `DispatchQueue.global().async` to prevent tap timeout. |
| 2026-06-04 | Changed volume step size from 2% to 16% per step, pxPerStep from 12 to 48 for volume, pxPerStep 11 for brightness (~9% faster), volume step cap from ±5 to ±1, brightness step cap stays ±5 | These are all user-requested tuning values. Document in ARCHITECTURE.md config table. Keep correction log entries for future tuning but don't revert without user request. |
| 2026-06-04 | Switched from CoreAudio to pure NSAppleScript and back twice during debugging | Verified: CoreAudio is correct primary path. NSAppleScript is async fallback. Pure NSAppleScript gave no benefit (same quantization) and lost device listener and float precision. |
