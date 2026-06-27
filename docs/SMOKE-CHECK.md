# SMOKE-CHECK.md — Pre-Commit Verification Checklist

**When to run:** before every commit that touches `Sources/trackpad-volume/main.swift`.

- [ ] **Volume** — Fn + vertical scroll changes volume (up and down, audible)
- [ ] **Brightness** — Fn + horizontal swipe changes brightness (left and right, visible)
- [ ] **Tap resilience** — after ~60s idle, Fn+scroll still works
- [ ] **No AX crash loop** — launch without Accessibility granted; app stays alive, no restart loop, no repeated popups
- [ ] **HUD appears** — Fn+vertical scroll shows HUD overlay top-center
- [ ] **HUD follows cursor** — move cursor to external monitor, scroll; HUD appears on that screen
- [ ] **HUD debounces** — fast scrolls cancel previous fade; HUD stays visible without flicker
- [ ] **HUD fades out** — stop scrolling; HUD fades after ~1.5s
- [ ] **HUD no-crash** — scroll 20+ times rapidly, then wait; app stays alive, event tap not disabled

**Logs:** `cat /tmp/trackpad-volume.log`
