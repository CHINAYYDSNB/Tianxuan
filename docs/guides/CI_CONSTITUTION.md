# CI Constitution v2.1 (Tianxuan Edition)

## 1. Commit Prefix System

| Prefix | Meaning | Can Merge to Main |
|--------|---------|-------------------|
| `test(:)` | Build APK only, no logic verified | ❌ NEVER |
| `wip(:)` | Work in progress, compiles, tests pass | ❌ Needs human review |
| `done(:)` | Human verified on physical device | ✅ Only after human says so |
| `shell(:)` | UI scaffold only, no logic | ❌ Must upgrade to wip first |
| `port(:)` | Code migrated from Lanxi/other repos | ❌ Must become wip/done |
| `refactor(:)` | Structural changes (Server Box inspired) | ❌ Needs human review |

**Banned Prefixes**: `fix(:)`, `feat(:)`, `chore(:)`

## 2. Code Bans

| Ban | Reason | CI Action |
|-----|--------|-----------|
| `print()` / `debugPrint()` | Use `appLogger` | Error + Fail |
| `expect(true, true)` | Fake test | Error + Fail |
| Single-quote `"$var"` in SSH | Shell injection / no interpolation | Warning |
| `UnimplementedError()` in production | Use `FallbackException` | Error + Fail |
| `if (isPanel)` / `if (useSSH)` in Service layer | Only Factory can branch | Error + Fail |
| Hardcoded credentials | Security | Error + Fail |
| `catch (_) {}` silent swallow | Hide errors | Error + Fail |
| File > 800 lines | Readability | Warning |
| Direct Dio/SSH in UI | Architecture violation | Error + Fail |

## 3. Testing Rules

- All external dependencies (Dio, dartssh2, SharedPreferences) MUST be mocked.
- Tests must use `verify()` to assert specific behavior.
- `mocktail` is the mocking library.
- Coverage threshold: **70%** (enforced by CI).
- No network calls in unit tests (even to localhost).

## 4. Architecture Bans

- UI files must NOT import `dio` or `dartssh2` directly.
- `ServerService` must have ZERO branching on channel type.
- `Factory` is the ONLY place allowed to decide API vs SSH.
- `FallbackServerSource` is the ONLY place allowed to catch `PanelFallbackException`.

## 5. Exception Handling

| Exception Class | When to Throw | Who Catches |
|----------------|---------------|-------------|
| `PanelFallbackException` | API returns non-200, timeout, 403/500 | `FallbackServerSource` |
| `SshAuthException` | All SSH auth methods fail | `SshSessionPool` |
| `SshPermissionException` | errno=1, port blocked, firewall | `SshServerSource` |
| `FileTooLargeException` | File > threshold and paged mode refused | `OnePanelAdapter` |

## 6. Performance Rules

- Monitor interval: exactly 1s (constant `kMonitorInterval = 1`).
- App paused → cancel all streams immediately.
- App resumed → rebuild streams.
- SSH heartbeat: 30s interval (keepalive NAT).
- Single SSH output > 4KB → truncate for UI display.
- Large file > 10MB → paged mode with Isolate.

## 7. Environment Contract

- Git proxy (local): `127.0.0.1:7897`
- Flutter Pub: needs proxy for pub.dev
- CI Flutter version: `3.24.5`
- CI runs on Ubuntu latest
- Node.js 24 forced (deprecation handling)
- No hardcoded proxy in code
- `gradle.properties` with proxy config → gitignored

## 8. Branch Naming

| Pattern | Purpose | Allowed to Merge Main |
|---------|---------|----------------------|
| `main` | Production | — |
| `phase<N>/feature-name` | Feature development | Via PR + human review |
| `phase<N>/feature-name-test` | Temporary CI build verification | ❌ Never |
| `hotfix/<issue>` | Emergency fix | Via PR |

## 9. Human Review Gate

- `done(:)` requires explicit human confirmation on physical device.
- AI must NOT self-promote `wip(:)` to `done(:)`.
- AI must NOT execute `git commit --amend`, `git rebase`, or force-push.
- PR description must include verification checklist.

## 10. History Integrity

- AI cannot modify git history.
- AI cannot amend commit messages.
- Changing commit prefix (e.g., `wip` → `done`) is human-exclusive.
- AI may suggest new commit messages, but human performs the amend.

## 11. Violation Matrix

| Violation | CI Action | AI Response |
|-----------|-----------|-------------|
| `print()` found | Error + Fail | Remove, use appLogger |
| `expect(true,true)` | Error + Fail | Write real assertion |
| Single-quote `$var` | Warning | Verify + fix interpolation |
| Coverage < 70% | Fail | Add tests |
| `test(:)` on main | Fail | Reject merge |
| `fix(:)` prefix | Warning | Change to wip/done |
| Network call in test | Fail | Mock the dependency |
| File > 800 lines | Warning | Split into modules |

## Appendix: build-apk.yml Quick Reference

Key CI steps (see build-apk.yml for full version):
1. Checkout → Setup Flutter 3.24.5 → pub get
2. dart format check → flutter analyze --fatal-infos
3. flutter test --coverage → 70% threshold check
4. flutter build apk --release → upload artifact
5. Anti-cheat scans (print, expect true, single-quote $var)
6. Block test: on main branch
7. Node 24 compatibility env vars
