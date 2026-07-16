# Palladium - Universal Portable Server Manager

Plug in a USB drive. Power up any Linux machine. Host anything.

Palladium turns any Linux computer into a portable server rack. Install once, carry it on a USB drive, and run your entire self-hosted stack from any machine — no reconfiguration needed.

## Quick Start

```bash
# 1. Clone or copy Palladium to your drive
git clone <this-repo> palladium

# 2. First-time setup
cd palladium
./setup.sh

# 3. Launch
./start.sh
# Or install system-wide:
sudo ./install.sh

# 4. Install services from the menu, or use the CLI:
palladium install ollama
palladium start ollama
```

## Directory Layout

```
palladium/
├── palladium/            CLI framework
│   ├── palladium         Main entry point
│   ├── modules/          Core modules (24)
│   ├── marketplace/      Tool catalog (.tool files)
│   ├── services/         Docker Compose templates
│   ├── stacks/           Pre-built stack bundles
│   └── data/             Runtime data
├── .env.example          Configuration template
├── setup.sh              First-time setup
├── start.sh              Launch the menu
├── stop.sh               Stop services
├── install.sh            Install CLI system-wide
└── tests/                Test suite
```

## Features

- **Portable** — Lives on a USB/SSD. Works on any Linux machine with Docker.
- **Service catalog** — 50+ pre-integrated services (AI, databases, automation, web)
- **Marketplace** — One-command install for Ollama, n8n, Postgres, Flowise, and more
- **Stacks** — Pre-built bundles: Starter (n8n+DB), Business, Dev, Production
- **AI Toolkit** — Local LLMs via Ollama, API connectors (OpenAI, Anthropic, Groq), RAG pipelines
- **Security** — Secrets manager, firewall setup, HTTPS certs, password audit
- **Backup & Clone** — Full service backup/restore, clone to another drive
- **Monitoring** — Resource usage, service health, live monitor, alerting

## Requirements

- Linux (any distribution)
- Docker & Docker Compose (auto-installed by setup.sh)
- Internet connection (for first-time pulls)

## CLI Reference

| Command | Description |
|---------|-------------|
| `palladium` | Launch interactive menu |
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

## Migrating from n8n-portable

If you were using the n8n-portable layout, your n8n instance is now available via:

```bash
palladium install n8n
palladium start n8n
```

Your existing data in `./data/` and `./postgres/` is preserved.
