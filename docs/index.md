# Palladium Documentation

Welcome to the official Palladium documentation. Palladium is a **Universal Portable Server Manager** that lets you run self-hosted services from a USB/SSD on any machine with Docker.

## Quick Links

- [Installation](guides/installation.md)
- [Getting Started](guides/getting-started.md)
- [CLI Reference](api/cli.md)
- [REST API](api/rest.md)
- [Marketplace](guides/marketplace.md)
- [AI Toolkit](guides/ai-toolkit.md)
- [Monitoring](guides/monitoring.md)
- [Backup & Restore](guides/backup.md)
- [Security](guides/security.md)
- [Plugin Development](guides/plugins.md)
- [Architecture](architecture/overview.md)
- [Contributing](contributing/guide.md)

## What is Palladium?

Palladium turns any USB drive or portable SSD into a **plug-and-play server**. Just plug it in, and you have:

- **50+ pre-integrated services** (databases, monitoring, AI, automation, web, DevOps)
- **AI Toolkit** - Local LLMs (Ollama), API connectors (OpenAI, Anthropic), RAG pipelines
- **Marketplace** - One-click install of 20+ self-hosted tools
- **Stacks** - Pre-built bundles (Starter, Business, Dev, Production)
- **Monitoring** - Prometheus + Grafana + Loki + Alertmanager
- **Backup/Clone** - Full disaster recovery, incremental backups, cloud sync
- **Security** - Encrypted secrets vault, 2FA, CIS Docker bench, audit logging
- **REST API** - Remote management, multi-host orchestration
- **Cross-platform** - Windows (Git Bash/WSL2), macOS, Linux, ARM

## Requirements

- Docker Engine 20.10+
- Docker Compose v2+
- 2GB+ RAM (4GB+ recommended for AI workloads)
- 10GB+ free space (more for services/data)

## Installation

### Windows (Recommended: WSL2)

```powershell
# Run as Administrator
wsl --install
# Restart, then:
wsl -d Ubuntu
curl -fsSL https://get.palladium.dev | bash
```

### macOS / Linux

```bash
curl -fsSL https://get.palladium.dev | bash
```

### Portable (USB/SSD)

```bash
# On any machine with Docker
git clone https://github.com/M-2000-0/Palladium.git /path/to/usb/palladium
cd /path/to/usb/palladium
./setup.sh
```

## Quick Start

```bash
# Start the interactive menu
palladium

# Or use CLI commands
palladium install n8n          # Install n8n workflow automation
palladium start n8n            # Start n8n
palladium status               # Show all services
palladium marketplace          # Browse marketplace
palladium ai                   # AI toolkit menu
palladium monitor              # Live system monitor
palladium backup               # Create backup
```

## Project Structure

```
palladium/
├── palladium/           # Core CLI framework
│   ├── palladium        # Main entry point
│   ├── modules/         # 27 core modules
│   ├── marketplace/     # 20+ tool definitions
│   ├── services/        # Docker Compose templates
│   ├── stacks/          # Pre-built stack bundles
│   └── data/            # Runtime data (gitignored)
├── VERSION              # Current version (1.1.0)
├── CHANGELOG.md         # Release history
├── .shellcheckrc        # Linting config
├── setup.sh             # First-time setup
├── plug-and-play.sh     # USB/SSD auto-detection
└── tests/               # Test suite (32 unit tests)
```

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.1.0 | 2026-07-19 | Plugin system, CI/CD, Marketplace v2, AI Toolkit v2, Monitoring Stack, Backup v2, Security Hardening |
| 1.0.0 | 2026-07-16 | Initial release: 9 marketplace tools, AI toolkit, stacks, monitoring, backup, security |

## Support

- **GitHub Issues**: [Bug reports & feature requests](https://github.com/M-2000-0/Palladium/issues)
- **Discussions**: [Community forum](https://github.com/M-2000-0/Palladium/discussions)
- **Security**: [SECURITY.md](SECURITY.md) for vulnerability reporting

## License

MIT License - see [LICENSE](LICENSE) for details.