# Reference Repository Index

This document maps each Task to its primary open-source reference. AI must read the referenced repo's `lib/` directory before implementing the corresponding Task.

---

## Phase 1: Infrastructure

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 01 ServerSource | flutter_server_box | ServerProvider SPI, dependency injection | UI, colors, assets |
| 02 SshSessionPool | CHINAYYDSNB/Lanxi + dartssh2 | Connection reuse, keepalive, reconnect | UI |
| 03 SshServerSource | flutter_server_box + Lanxi | Command execution pattern, output parsing | UI |
| 04 OnePanelAdapter | bin64/Mono-Dash | API endpoints, DTO structure, md5 auth | UI |
| 05 FallbackServerSource | flutter_server_box | API-to-SSH routing logic | UI |
| 06 Factory | 1Panel-Client (IsKenKenYa) | Multi-server config routing | UI |
| 07 ServerService | bin64/Mono-Dash | Facade organization | UI |
| 08 CI | (rules only) | — | — |

---

## Phase 2: Dashboard & Monitoring

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 09 SSH Stream (1s) | server_monitor (tresanti) + flutter_server_box | top/free/df regex, Stream driving | UI cards |
| 10 Dashboard UI | flutter_server_box | Data binding to charts | Card styling, colors |

---

## Phase 3: File Management

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 12 File List | bin64/Mono-Dash + Blink | 1Panel file API fields, SFTP listing | UI |
| 13 Editor | flutter_code_editor (pub.dev) + Lanxi | Editor integration, SSH backup write | UI |
| 13b Image Preview | nbox (nbcx) + photo_view | photo_view zoom, cached_network_image | UI |
| 13c Read-only Preview | flutter_code_editor | ReadOnly mode | UI |
| 13d Chunked Loading | TeleBook (dorkytiger) | Isolate usage, paging logic | UI |
| 14 Compress | flutter_archive (li8607) + Lanxi | Native zip, SSH tar fallback | UI |

---

## Phase 4: Docker

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 16 Container List | bin64/Mono-Dash + flutter_server_box | Container API fields, SSH docker ps | UI |
| 17 Container Ops | bin64/Mono-Dash | API endpoints for start/stop | UI |
| 18 Log Streaming | Blink (dorkytiger) + Linxr (AI2TH) | Shell stdout streaming, docker logs -f | UI |
| 19 Image Management | bin64/Mono-Dash | Image API endpoints | UI |

---

## Phase 5: New Features

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 20 Terminal | Blink + Linxr + dartssh2 examples | xterm rendering, PTY resize, auto-reconnect | UI |
| 21 System Settings | flutter_server_box | SSH command patterns for NTP/DNS/passwd | UI |
| 22 Cron Jobs | bin64/Mono-Dash (cronjob_v2) + flutter_server_box | Cron API fields, crontab fallback | UI |

---

## Phase 6: Websites & Firewall

| Task | Reference Repo | What to Learn | What NOT to Copy |
|------|---------------|---------------|------------------|
| 23 Website Preview | bin64/Mono-Dash (website_v2) | Site list API, Nginx config read | UI |
| 24 Firewall | bin64/Mono-Dash (firewall_v2) + flutter_server_box | ufw/firewalld SSH fallback | UI |

---

## Dependency List (pubspec.yaml)

### Required
| Package | Purpose | Reference |
|---------|---------|-----------|
| dartssh2 | SSH protocol | dartssh2 official |
| flutter_code_editor | Code editor + syntax highlighting | pub.dev |
| photo_view | Image zoom/preview | pub.dev |
| cached_network_image | Image caching | pub.dev |
| flutter_secure_storage | Credential storage | pub.dev |
| inspire_blur | Glassmorphism UI | Mono-Dash uses it |
| appLogger | Logging (project internal) | Lanxi |

### Future (Phase 7)
| Package | Purpose |
|---------|---------|
| syncfusion_flutter_pdfviewer | PDF preview |
| file_picker | Local file selection |

---

## Repository Addresses (Verified)

| Name | URL |
|------|-----|
| Tianxuan (base) | https://github.com/CHINAYYDSNB/Tianxuan |
| Lanxi (SSH core) | https://github.com/CHINAYYDSNB/Lanxi |
| Mono-Dash (API template) | https://github.com/bin64/Mono-Dash |
| flutter_server_box | https://github.com/lollipopkit/flutter_server_box |
| Blink | https://github.com/dorkytiger/Blink |
| TeleBook | https://github.com/dorkytiger/TeleBook |
| Linxr | https://github.com/AI2TH/Linxr |
| nbox | https://github.com/nbcx/nbox |
| flutter_archive | https://github.com/li8607/flutter_archive |
| 1Panel-Client | https://github.com/IsKenKenYa/1Panel-Client |
| server_monitor | https://github.com/tresanti/server_monitor |
