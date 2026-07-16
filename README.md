# Palladium — Universal Portable Server Manager

[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
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
- **Service catalog** — 50+ pre-integrated services (AI, databases, automation, web)
- **Marketplace** — One-command install: Ollama, n8n, Postgres, Flowise, Supabase, and more
- **Stacks** — Pre-built bundles: Starter (n8n+DB), Business, Dev, Production
- **AI Toolkit** — Local LLMs (Ollama), API connectors (OpenAI, Anthropic, Groq), RAG pipelines
- **Dashboard** — Interactive terminal UI (Claude Code–style) with services, resources, URLs
- **Security** — AES-256 secrets vault, firewall setup, HTTPS certs, password audit
- **Backup & Clone** — Full service backup/restore, clone to another drive
- **Monitoring** — CPU/RAM/Disk live monitor, service health, alerting (Telegram/email)
- **USB Autorun** — Plug-and-play: insert USB, Palladium starts automatically

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
│   ├── modules/          29 core modules
│   ├── marketplace/      Tool catalog (.tool files)
│   ├── services/         Docker Compose templates
│   ├── stacks/           Pre-built stack bundles
│   └── data/             Runtime data
├── VERSION               1.0.0
├── CHANGELOG.md          Release history
├── SECURITY.md           Vulnerability reporting
├── setup.sh              First-time setup
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
