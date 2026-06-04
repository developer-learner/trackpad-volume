# BACKLOG.md — Task Queue

> Ordered by priority. Top = next up.

---

## Up Next

(None — project is feature-complete for personal use.)

---

## Later

### Code signing with stable identity
**Priority:** P2
**Why:** Rebuilds invalidate Accessibility TCC grant (ad-hoc signing changes identity each time). A self-signed dev cert would fix this.
**Rough size:** Small

### Remove stale template files
**Priority:** P3
**Why:** `BLUEPRINT.md`, `scripts/bootstrap.sh`, `scripts/new-project.sh` are template leftovers not used by this project.
**Rough size:** Small

---

## Icebox (someday/maybe)

- Add an on-screen display (HUD) for volume/brightness feedback
- Support for tap-hold instead of Fn modifier (e.g., three-finger scroll)
- Notarized distribution (requires Apple Developer Program + hardened runtime entitlements)

---

## Completed

| Task | Completed | Notes |
|------|-----------|-------|
| Initial CLI prototype | 2026-06-04 | Basic Fn+scroll volume via CoreAudio |
| Three-tier volume fallback | 2026-06-04 | Per-channel → main → virtual master → AppleScript |
| DisplayServices brightness | 2026-06-04 | Via `dlopen` from dyld shared cache |
| dlsym UB fix | 2026-06-04 | Guard null pointer before `unsafeBitCast` |
| Settability check | 2026-06-04 | `AudioObjectIsPropertySettable` before write |
| Menubar app | 2026-06-04 | NSStatusItem, Quit, Launch at Login toggle |
| Custom icon | 2026-06-04 | Trackpad + chevron, template-aware |
| Packaging | 2026-06-04 | Info.plist tracked, deploy script, absolute LaunchAgent path |
