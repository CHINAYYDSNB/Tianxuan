# Role: Senior Flutter Architect & DevOps Engineer

## 0. Core Identity & Constraints
You are refactoring the `CHINAYYDSNB/Tianxuan` repository.
- **Base Repository**: Tianxuan (Target)
- **Architecture Shadow**: `lollipopkit/flutter_server_box` (Skeleton ONLY)
- **SSH Core**: `CHINAYYDSNB/Lanxi` (Old repo, high priority)
- **API Template**: `bin64/Mono-Dash` (Correct repo, NOT nowubh)
- **No UI Plagiarism**: NEVER copy Widget trees, color schemes, or assets from reference repos. Logic and architecture are encouraged; UI must be original.
- **No Sync**: Permanently remove iCloud Keychain and WebDAV related code/logic.

## 1. Architectural Principles (The "Shadow" Rules)
- **SPI Pattern**: Use `ServerSource` (Abstract) -> `ApiServerSource` / `SshServerSource` (Implementations).
- **API First, SSH Fallback**: Always attempt 1Panel API first. Only use SSH (`SshServerSource`) if API fails or is unavailable.
- **Single Source of Truth**: `Mono-Dash` defines API contracts. `Lanxi` defines SSH command patterns.
- **Lifecycle Awareness**: All polling (e.g., 1s monitor) must stop on `AppLifecycleState.paused` and resume on `resumed`. Use `AppLifecycleListener`.

## 2. Module-Specific Directives

### 2.1 Monitoring (1s Refresh)
- **Frequency**: Exactly 1 second when app is active. Stop when inactive.
- **Source**: Pure SSH (`top -bn1`, `free -m`, `df -h`).
- **Parsing**: Port regex logic directly from `CHINAYYDSNB/Lanxi`. Do not reinvent parsers.

### 2.2 File Editor & Large Files
- **Kernel**: `flutter_code_editor`.
- **Save Logic (SSH)**:
  1. Backup: `cp $path $path.bak.$(date +%s)`
  2. Write: `cat > $path <<'LANXI_EOF'` (Use single quotes to prevent variable expansion).
- **Large File Handling**:
  - > 1MB: Show warning dialog.
  - > 10MB: Enforce Paged Mode.
  - **Paging**: Use `RandomAccessFile` or SSH `head/tail`. NO full file loading into memory. Reference: `dorkytiger/TeleBook`.
  - **Isolate**: Perform heavy parsing in Isolates to keep UI smooth.

### 2.3 Docker & Logs
- **Logs Streaming**: Prefer API streaming. Fallback: SSH `docker logs -f`.
- **PTY**: For interactive terminals, reference `dorkytiger/Blink` for PTY handling.

### 2.4 Cron & Firewall
- **Cron**: Use `crontab -l` / `-e` via SSH.
- **Firewall**: Use `ufw` or `firewalld` commands via SSH.

## 3. CI & Commit Protocol
- **Prefixes**:
  - `wip(:)`: Work in progress (Compiles, tests pass, but human verification pending).
  - `done(:)`: Human verified on physical device.
  - `port(:)`: Code migrated from Lanxi or other repos.
  - `refactor(:)`: Structural changes following `flutter_server_box` patterns.
- **Quality Gates**:
  - `flutter analyze`: Must pass with `--fatal-infos`.
  - `flutter test`: 100% pass required.
  - Coverage: Must exceed 70%.
- **Security**: Never expose tokens in logs. Use `flutter_secure_storage` for credentials.

## 4. Reference Repository Map (Read Before Coding)
1. **Skeleton**: `lollipopkit/flutter_server_box` (Provider/SPI patterns)
2. **SSH**: `CHINAYYDSNB/Lanxi` (Command patterns, SessionPool)
3. **API**: `bin64/Mono-Dash` (Endpoint URLs, DTOs)
4. **Streaming**: `dorkytiger/Blink` (Shell/PTY streams)
5. **Chunking**: `dorkytiger/TeleBook` (Isolate, paging)

## 5. Task Phases

### Phase 1: Infrastructure
- Task 01: Create ServerSource abstract interface
- Task 02: Port SshSessionPool + SshConnection from Lanxi
- Task 03: Port SshServerSource (heartbeat, reconnect)
- Task 04: Refactor Tianxuan Dio code into OnePanelAdapter
- Task 05: Implement FallbackServerSource (API -> SSH auto-degrade)
- Task 06: Implement ServerSourceFactory (route by credentials)
- Task 07: Implement ServerService (Facade, zero branching)
- Task 08: Setup CI (build-apk.yml + iron rules)

### Phase 2: Dashboard & Monitoring
- Task 09: SSH stream integration (top/free/df, 1s interval)
- Task 10: Dashboard UI (cards + line charts)

### Phase 3: File Management
- Task 12: File list API + UI
- Task 13: Online editor (flutter_code_editor + SSH backup write)
- Task 13b: Image preview (photo_view + cached_network_image)
- Task 13c: Document read-only preview
- Task 13d: Large file chunked loading (Isolate + paging)
- Task 14: Compress/decompress (API first + SSH tar fallback)

### Phase 4: Docker
- Task 16: Container list API + UI
- Task 17: Container start/stop/restart/delete
- Task 18: Log streaming (API first, SSH docker logs -f fallback)
- Task 19: Image management

### Phase 5: New Features
- Task 20: Built-in SSH terminal (from Lanxi + Blink reference)
- Task 21: System settings (NTP/DNS/timezone/root password, SSH only)
- Task 22: Cron jobs (API first + crontab fallback)

### Phase 6: Websites & Firewall
- Task 23: Website preview (API only, read-only)
- Task 24: Firewall (API first + ufw fallback)

### Phase 7: Future (Not Scheduled)
- PDF/Office preview
- Backup/snapshot management
- HTTPS certificate management
- Log audit (system/login/SSH/container)

## 6. Current Task Context
- We are currently in **Phase 3: File Management**.
- Focus: Implementing the Online Editor with paged loading for large files.
- Next: Docker Log Streaming.
