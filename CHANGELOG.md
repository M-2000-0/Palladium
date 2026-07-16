# Changelog

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
