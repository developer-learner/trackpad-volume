# DECISIONS.md — Architectural Decision Log

> Every non-obvious technical decision goes here with the reasoning.
> This prevents the LLM from "helpfully" undoing choices you already made.
> Format: date, decision, why, what not to suggest.

---

## Template

```
## YYYY-MM-DD — [Decision title]

**Decision:** [What was decided]
**Alternatives considered:** [What else was evaluated]
**Reason:** [Why this choice was made]
**Do not suggest:** [What the LLM should not propose as a "fix"]
```

---

## Decisions

## 2026-06-27 — No synchronous UI in event-tap callback path

**Decision:** No synchronous UI (alerts, popups, modal dialogs, or anything
that blocks the main thread or the RunLoop) in the CGEventTap callback path
or any code reachable from the scroll-wheel handler.

**Alternatives considered:** Dispatch the HUD overlay to a background queue
or use non-blocking feedback (NSSound.beep, transient NSStatusItem highlight).
These were not adopted at the time — the synchronous approach was simpler.

**Reason:** A synchronous volume-change popup in the event-tap callback
caused a cascade: blocking the callback triggered kCGEventTapDisabledByTimeout,
which combined with KeepAlive+terminate into a crash loop, and masked the
deletion of the `eventTap = tap` reference that the re-enable path depends on.
The CGEventTap contract requires callbacks to return promptly.

**Do not suggest:** Re-adding synchronous UI in the callback path. Any
user-facing feedback must use non-blocking dispatch only.

## 2026-06-27 — Volume HUD: NSWindow + NSView draw(:), cursor-follows, no dependency

**Decision:** Implement the volume HUD as an `NSWindow` with a custom `NSView` subclass that draws via `draw(_:)`. Positioned top-center of the screen containing the cursor. Fades in over 0.15s, displays for 1.5s, fades out over 0.3s. Debounced via `cancelPreviousPerformRequests` pattern.

**Alternatives considered:** Third-party HUD library, SwiftUI overlay, IOKit backlight overlay, NSPopover, NSAlert. All rejected for either dependency weight, threading complexity, or blocking behavior.

**Reason:** NSWindow + draw(_:) is zero-dependency, sub-millisecond draw, uses only Foundation/AppKit already available. The non-blocking dispatch (`DispatchQueue.main.async` from the CoreAudio write path) keeps the HUD off the event-tap thread entirely, respecting the "no sync UI in callback path" decision above.

**Do not suggest:** Changing to SwiftUI (requires new dependency chain), adding a library (SFSymbols, etc.), moving HUD to a background thread (NSView must be on main), or showing the HUD from within the event-tap callback.

---

> Add new decisions above this line, newest first.
