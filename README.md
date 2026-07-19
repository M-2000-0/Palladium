# Palladium — Universal Portable Server Manager

[![Version](https://img.shields.io/badge/version-1.2.0-blue)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()

> **Plug in a USB drive. Power up any machine. Host anything.**

Palladium turns any computer into a portable server rack. Install once, carry it on a USB/SSD, and run your self-hosted stack on any machine — no reconfiguration needed.

Cross-platform: **Windows** (Git Bash), **macOS**, **Linux** (any distro), **ARM** (Raspberry Pi).

---

## Quick Start

**One-line install:**

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/M-2000-0/Palladium/main/palladium/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/M-2000-0/Palladium/main/palladium/install.ps1 | iex
```

**Or clone and run:**

```bash
git clone https://github.com/M-2000-0/Palladium.git palladium
cd palladium
./setup.sh          # first-time setup
./start.sh          # launch the menu
```

**Install tools & go:**

```bash
palladium install-tools    # installs Git, Docker, Python, Node.js, VS Code
palladium marketplace      # browse 50+ services
palladium stack starter    # one-command full stack
palladium dashboard        # live server overview
```

---

## Features

- **Portable** — Lives on a USB/SSD. Works on any machine with Docker.
- **Service catalog** — 50+ services via marketplace + AI app catalog (AI, databases, DevOps, web, messaging)
- **Marketplace** — One-command install: Ollama, n8n, Postgres, Grafana, Portainer, MinIO, and more
- **Stacks** — Pre-built bundles: Starter (n8n+DB), Business, Dev, Production
- **AI Toolkit** — Local LLMs (Ollama), API connectors (OpenAI, Anthropic, Groq), RAG pipelines
- **Dashboard** — Interactive terminal UI (Claude Code–style) with services, resources, URLs
- **Security** — AES-256 secrets vault, firewall setup, HTTPS certs, password audit
- **Backup & Clone** — Full service backup/restore, clone to another drive
- **Monitoring** — CPU/RAM/Disk live monitor, service health, alerting (Telegram/email)
- **USB Autorun** — Plug-and-play: insert USB, Palladium starts automatically

## Why USB?

Palladium is designed to live on a USB stick or portable SSD. Here's why that matters:

**Portability** — Your entire server stack fits in your pocket. Plug into any Windows/Mac/Linux machine, run one command, and n8n + Postgres + Ollama are ready. Move between machines without reinstalling or reconfiguring.

**No cloud lock-in** — Your data, credentials, and config travel with the physical drive. No subscription, no vendor dependency, no data leaving your control.

**Disaster-proof** — Laptop dies or gets stolen? Plug your USB into any other computer and resume working. No backup restore needed — the drive *is* the backup.

**Ephemeral hosts** — Use library computers, hotel PCs, or a friend's laptop. Palladium runs entirely from the USB and leaves no trace when you unplug.

**Air-gap capable** — After the initial install, everything runs offline. No internet required for daily operation. Great for demos, travel, or secure environments.

**Works without USB too** — Run `install.sh` directly on your machine and Palladium deploys to `~/palladium`. You lose portability, but everything else works the same.

## Requirements

- **Any OS:** Windows (Git Bash), macOS, Linux, ARM
- **Docker** (auto-installed by `palladium install-tools` or `setup.sh`)
- Internet connection (for first-time pulls)

## CLI Reference

| Command | Description |
|---------|-------------|
| `palladium` | Launch interactive menu |
| `palladium dashboard` | Live server dashboard (TUI) |
| `palladium install-tools` | Install Git, Docker, Python, Node.js, VS Code |
| `palladium install <name>` | Install a service |
| `palladium start <name>` | Start a service |
| `palladium stop <name>` | Stop a service |
| `palladium status` | Show all services |
| `palladium logs <name>` | View service logs |
| `palladium remove <name>` | Remove a service |
| `palladium list` | List installed services |
| `palladium marketplace` | Browse the tool catalog |
| `palladium stack <name>` | Install a pre-built stack |
| `palladium ai` | AI toolkit menu |
| `palladium backup` | Backup all services |
| `palladium restore` | Restore from backup |
| `palladium cleanup` | Free up Docker space |
| `palladium uninstall` | Remove Palladium from the system |
| `palladium --version` | Show version |
| `palladium --debug` | Run with debug logging |

## Directory Layout

```
palladium/
├── palladium/            CLI framework
│   ├── palladium         Main entry point
│   ├── modules/          27 core modules
│   ├── marketplace/      22 tool catalog (.tool files)
│   ├── services/         Docker Compose templates (with healthchecks)
│   ├── stacks/           Pre-built stack bundles
│   └── data/             Runtime data
├── VERSION               1.1.0
├── .shellcheckrc         ShellCheck linting config
├── CHANGELOG.md          Release history
├── SECURITY.md           Vulnerability reporting
├── setup.sh              First-time setup
├── plug-and-play.sh      Plug-and-play launcher (OS/USB/Docker detection)
├── start.sh              Launch the menu
├── stop.sh               Stop services
├── install.sh            Install CLI system-wide
├── uninstall.sh          Remove from system
└── tests/                Test suite (32 unit tests)
```

## Migrating from n8n-portable

```bash
palladium install n8n
palladium start n8n
```

Your existing data in `./data/` and `./postgres/` is preserved.

## Open-source release model

This project follows an optional, versioned release model:

- Releases are documented as milestones such as Update 1.0, Update 1.1, and so on
- Users are never forced to upgrade
- Older versions remain usable and can be kept indefinitely
- New releases are additive and optional
- Users can roll back to a previous update whenever they want

For the full release philosophy and current release notes, see [releases/README.md](releases/README.md).
