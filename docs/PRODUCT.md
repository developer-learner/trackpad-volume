# PRODUCT.md — Product Context

> Evergreen. Describes what we're building and who it's for.
> Not a task list — that's in tasks/. This is the "why" layer.

---

## Problem Statement

macOS has no built-in way to adjust volume or brightness using trackpad
gestures. Apple keyboards with Touch Bar or without function keys make
dedicated media keys unavailable. Third-party solutions exist but are heavy
(menu bar apps, preference panes, subscription models). This tool solves
one thing: Fn+trackpad volume and brightness, nothing else.

---

## Target Users

| User type | Description | Primary need |
|-----------|-------------|--------------|
| MacBook users | Built-in keyboard lacks function/media keys | Volume control without reaching for Touch Bar or menu bar |
| External keyboard users | Mechanical/compact keyboards without media keys | Volume + brightness via the trackpad they're already using |
| Minimalists | Want one utility that does one thing well | No background daemons, no subscriptions, no UI |

---

## Core Value Proposition

"Hold Fn, scroll on the trackpad — volume changes. Swipe horizontally — brightness changes. No windows, no menus, no configuration."

---

## What We Are Not Building

- Not a media player controller (no play/pause/skip)
- Not an on-screen display (no HUD)
- Not a system preference pane
- Not a subscription service
- Not a menu bar app (uses status item only for Quit + Launch at Login)

---

## Success Metrics

| Metric | Target | How measured |
|--------|--------|--------------|
| Latency | < 50ms from scroll to audible volume change | Subjective / slow-mo recording |
| Crash rate | 0 crashes per session | Console.app crash reports |
| Volume range | 0–100% across all devices | Tested on headphones, built-in speakers, external DAC |
