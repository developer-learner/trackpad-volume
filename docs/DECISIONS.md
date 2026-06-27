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

---

> Add new decisions above this line, newest first.
