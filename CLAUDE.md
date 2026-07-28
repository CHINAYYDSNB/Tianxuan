# Tianxuan — Project Guide

> See `docs/guides/` for full reference documents.

## Commit Prefixes

| Prefix | Use |
|--------|-----|
| `wip(:)` | Work in progress |
| `done(:)` | Human verified |
| `port(:)` | Code from Lanxi |
| `refactor(:)` | Structural changes |
| `test(:)` | Build-only |
| `shell(:)` | UI scaffold |
| **Banned**: `fix:`, `feat:`, `chore:` |

## Core Architecture

```
ServerService (Facade) → ServerSource (SPI)
  ├─ ApiServerSource       ← 1Panel API
  ├─ SshServerSource       ← SSH fallback
  └─ FallbackServerSource  ← auto degrade
```

- **UI** cannot import `dio` / `dartssh2`
- **Service** zero branching on channel type
- **Factory** is sole routing decision point
- **No `print()`** → use `appLogger`
- **No `UnimplementedError()`** → use domain exceptions

## SSH Write Rules

```dart
// Always: quoted heredoc prevents shell expansion
ssh.exec("cat > \"$path\" <<'LANXI_EOF'\n$content\nLANXI_EOF");
// Always: backup first
ssh.exec("cp \"$path\" \"$path.bak.$(date +%s)\"");
```

- Files >1MB: warning dialog; >10MB: forced paged mode with Isolate
- Dart SSH strings **must use double quotes** (single quotes don't interpolate)

## References

| Role | Repo |
|------|------|
| Skeleton | `lollipopkit/flutter_server_box` (logic only, NO UI copy) |
| SSH | `CHINAYYDSNB/Lanxi` |
| API | `bin64/Mono-Dash` (NOT nowubh) |
| Terminal | `dorkytiger/Blink` |
| Chunking | `dorkytiger/TeleBook` |

## Key Files

- `docs/guides/CI_CONSTITUTION.md` — Full CI rules & bans
- `docs/guides/SSH_WRITE_RULES.md` — Non-negotiable SSH patterns
- `docs/guides/SYSTEM_PROMPT.md` — AI architect system prompt
- `docs/guides/REFERENCE_REPOS.md` — Per-task reference mapping
- `docs/guides/HUMAN_GUIDE.md` — Human operator checklist
- `docs/guides/STARTUP_PROMPT.txt` — AI session start template
