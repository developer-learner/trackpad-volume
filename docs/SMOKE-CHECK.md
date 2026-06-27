# SMOKE-CHECK.md — Pre-Commit Verification Checklist

**When to run:** before every commit that touches `Sources/trackpad-volume/main.swift`.

- [ ] **Volume** — Fn + vertical scroll changes volume (up and down, audible)
- [ ] **Brightness** — Fn + horizontal swipe changes brightness (left and right, visible)
- [ ] **Tap resilience** — after ~60s idle, Fn+scroll still works
- [ ] **No AX crash loop** — launch without Accessibility granted; app stays alive, no restart loop, no repeated popups

**Logs:** `cat /tmp/trackpad-volume.log`
