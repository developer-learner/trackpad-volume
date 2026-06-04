# CONVENTIONS.md — Code Style & Patterns

> Rules for every code change in this project.

---

## Swift Style

```swift
// ✅ Type inference where obvious
let volume: Float32 = 0.2

// ✅ Explicit types on function signatures
func changeVolume(deltaSteps: Int) { ... }

// ✅ guard-let early return over nested if-let
guard let get = displayServices.get else { return }

// ❌ Never force-unwrap (!) unless proven safe in the same line
let x = dict["key"]!  // NO

// ❌ Never try! — handle errors
try! someThrowingFunc()  // NO

// ✅ File-private by default, internal when needed
private func helper() { ... }
```

## Conventions

- Single-file CLI/app (keep it that way unless it grows significantly)
- `print()` is fine for CLI debug output (no logger library available)
- Prefer simple functions with file-private scope; no classes unless state requires it
- `DispatchQueue.global().async` for offloading work from event-tap thread

## Git Commit Messages

```
<type>: <short description>

feat: add three-tier volume fallback
fix: check dlsym return before unsafeBitCast
chore: add ServiceManagement framework
docs: update README for menubar app
```
