# Changelog

## [1.2.0] - 2026-07-19

### Added
- **Plugin System** — Dynamic plugin loading (`load_plugins`), install/enable/disable/create commands (`plugin_install`, `plugin_enable`, `plugin_disable`, `plugin_list`, `plugin_create`), sample `hello-world` plugin
- **GitHub Actions CI/CD** — shellcheck linting, unit tests, plugin tests, Docker Compose validation, automated releases on tags
- **Marketplace v2** — Tool ratings (`marketplace_rate`), update checks (`marketplace_check_updates`, `marketplace_update_tool`), community submissions (`marketplace_submit`), ratings display (`marketplace_ratings`)
- **AI Toolkit v2** — Ollama Model Manager (`ai_ollama_models`), RAG Pipeline Builder (`ai_rag_builder`), Prompt Template Library (`ai_prompt_library`)
- **Monitoring Stack** — Full observability: Prometheus + Grafana + Loki + Promtail + Alertmanager with 4 pre-built dashboards (System, Containers, Services, Overview), 25+ alert rules
- **Backup/Clone v2** — Incremental rsync (`backup_incremental`), restic encrypted deduplicated backups (`backup_restic`), rclone cloud sync S3/GDrive/Azure (`backup_rclone`), age-encrypted tarballs (`backup_encrypted`), scheduled backups via cron (`backup_schedule`)
- **Security Hardening** — TOTP 2FA (`security_2fa`), audit log viewer (`security_audit_log`), secrets rotation with age/expiration (`security_secrets_rotation`), CIS Docker Benchmark runner (`security_cis_docker_bench`)
- **REST API Server** — Flask-based API on port 8080 with Bearer auth: status, services CRUD, stacks, backup, marketplace, AI models, multi-host proxy
- **Windows Native Packaging** — WiX MSI installer (`.wxs`), Chocolatey package (`chocolateyinstall.ps1`, `.nuspec`), Winget manifest (`.yaml`), WSL2 auto-setup script (`wsl2-setup.ps1`)
- **Documentation Site** — Markdown docs: index, installation, getting started, CLI reference, REST API, marketplace, AI toolkit, monitoring, backup, security, plugins, architecture, contributing

### Changed
- Main entry point now loads `api.sh` module and plugin system
- Security menu reorganized with hardening section (options 6-9)
- Marketplace browse menu adds ratings (r), updates (u), submit (s) shortcuts
- AI menu adds Ollama Models, RAG Builder, Prompt Library options

### Fixed
- API key generation uses secure random bytes
- Plugin loading validates structure before sourcing
- Restore handles encrypted backups correctly
- WSL2 setup enables systemd and Docker integration

## [1.1.0] - 2026-07-19

### Added
- `sed_inplace()` — cross-platform `sed -i` that works on macOS and Linux
- `validate_sql_input()` — SQL injection prevention in Data workspace
- First-run welcome message with quick-start guide
- Plug-and-play detection flow: OS detection, USB/SSD detection, Docker check, first-run setup
- Shared `palladium` Docker network for inter-service communication
- `healthcheck:` directives on all service templates (n8n, PostgreSQL, Redis, Nginx)
- 12 new marketplace tools: Portainer, Grafana, Prometheus, MinIO, Dozzle, Beszel, pgAdmin, InfluxDB, Caddy, RabbitMQ, Gitea, Mosquitto
- Messaging and Storage categories in marketplace
- `.shellcheckrc` for project linting configuration
- AI API keys now optionally stored in encrypted secrets vault
- `updates.sh` checks GitHub releases API for latest version and offers auto-update
- File locking (`with_lock`) wired into `svc_start` for concurrent safety
- `.initialized` marker file for first-run detection

### Changed
- AI mega-menu (`ai_setup_apps`) rewritten from 83 fictional Docker images to 30 real self-hosted apps using data-driven array
- Marketplace expanded from 9 to 22 tools
- Marketplace browse menu now includes 8 categories: AI, Data, Automation, Web, DevOps, Messaging, Storage, All
- Compose templates no longer use deprecated `version: "3.8"` field
- Stack installer generates secure random passwords instead of hardcoded `changeme`
- `cd` commands in service operations now have error handling
- `plug-and-play.sh` rewritten with full OS detection, Docker readiness check, and first-run flow

### Fixed
- Removed duplicate `port_in_use()`/`port_exposed()` definitions from `security.sh` and `network.sh` (consolidated in `safety.sh`)
- `sed -i` macOS incompatibility across all modules
- Hardcoded `changeme` passwords in stack installer
- `production.stack` misleading description (was "Full monitoring stack", now "Production database and cache layer")
- `dev.stack` description improved for clarity

## [1.0.0] - 2026-07-16

### Added
- Cross-platform OS detection (`detect_os`) — auto-detects Windows/Mac/Linux
- `palladium install-tools` — one-command setup of Git, Docker, Python, Node.js, VS Code
- `palladium dashboard` — interactive terminal dashboard (Claude Code-style TUI)
- `palladium --version` / `-v` flag
- `palladium uninstall` command
- `palladium --debug` / `-d` flag with logging
- `uninstall.sh` and `uninstall.ps1` scripts
- `SECURITY.md` for vulnerability reporting
- `packages.sh` module — cross-platform package management
- `dashboard-tui.sh` module — terminal UI dashboard
- `ensure_docker_in_path()` — finds Docker CLI on Windows outside PATH
- `find_windows_exe()` — searches common install paths on Windows

### Changed
- Menu layout: two-column grid (numbered 1-17 + 0 for Exit)
- `install_docker()` — cross-platform: winget (Windows), brew (macOS), multi-PM (Linux)
- `check_docker_available()` — uses `find_docker_cli()` for broader detection
- Banner: full 6-line ASCII logo restored
- `watch-usb.ps1` — closes File Explorer windows, uses `AppActivate` for foreground
- Secrets vault: upgraded from deprecated `-salt` to `-pbkdf2 -iter 100000`
- README: fixed placeholder URLs, added badges, one-liner install

### Fixed
- `detect_usb_drive()` return value causing `set -e` silent exit
- Menu alignment: Unicode char count via `wc -m` instead of `${#var}` (byte count)
- `sudo apt` error on Windows by detecting OS before package installation
