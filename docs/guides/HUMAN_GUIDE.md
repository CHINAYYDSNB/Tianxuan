# Tianxuan Refactoring Guide (Human Operator)

## Project Goal
Transform Tianxuan into a robust server manager using Lanxi's SSH power and Mono-Dash's API structure, wrapped in a stable architecture inspired by flutter_server_box.

## Architecture Shadow Concept
- **What to Copy**: SPI layering, Stream management, Lifecycle hooks, Error handling patterns.
- **What NOT to Copy**: Widget trees, Color schemes, Asset files, UI layouts.
- **Analogy**: Think of Server Box as the skeleton. We keep its bones, but give it new skin (Tianxuan UI), new heart (Lanxi SSH), and new blood (Mono-Dash API).

## Development Phases

### Phase 1: Infrastructure (Done)
- Established ServerSource SPI.
- Ported SSH kernel from Lanxi.
- Setup CI with quality gates.

### Phase 2: Monitoring (Done)
- 1s real-time SSH polling.
- Dashboard cards with charts.

### Phase 3: File Management (In Progress)
- **Editor**: Test saving a file. Check if `.bak` file is created on server.
- **Large Files**: Open a 50MB log file. Does the app lag? Does paging work?
- **Images**: Open a PNG/JPG. Can you zoom and pan?

### Phase 4: Docker
- **Logs**: Test `docker logs -f`. Does it stream smoothly?

### Phase 5: New Features
- **Terminal**: Test resizing the window. Does the remote shell adapt?
- **Cron/Firewall**: Test adding a cron job via SSH.

## How to Command AI
1. **Start Prompt**: Copy contents of `STARTUP_PROMPT.txt`.
2. **Specific Tasks**: "Refactor file saving to use the SSH backup logic defined in SYSTEM_PROMPT."
3. **Review**: Check AI's `pubspec.yaml` changes. Ensure no UI packages from reference repos are added unnecessarily.

## Verification Checklist (Before `done(:)`)
- [ ] Feature works on Android Physical Device.
- [ ] Kill and relaunch app, state persists (if applicable).
- [ ] No new `print()` statements left in production code.
- [ ] CI passes (Analyze, Test, Coverage).
- [ ] Large file (>10MB) opens in paged mode without OOM.

## Important Notes
- **Mono-Dash Repo**: It is `bin64/Mono-Dash`. If AI tries to use `nowubh`, correct it.
- **SSH Writing**: Always use `<<'LANXI_EOF'` for multi-line writes to prevent shell injection or variable expansion errors.
- **No Sync**: Do not re-add iCloud or WebDAV features.
- **1s Monitor**: Must stop when app goes to background. Check battery usage.

## Reference Repository Quick Links
1. **flutter_server_box**: https://github.com/lollipopkit/flutter_server_box
2. **Lanxi (SSH Core)**: https://github.com/CHINAYYDSNB/Lanxi
3. **Mono-Dash (API)**: https://github.com/bin64/Mono-Dash
4. **Blink (Terminal)**: https://github.com/dorkytiger/Blink
5. **TeleBook (Chunking)**: https://github.com/dorkytiger/TeleBook
