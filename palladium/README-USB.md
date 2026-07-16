# Palladium Portable Server — USB/SSD Edition

**Your server. Your data. Your pocket.**

---

## What Is This?

A complete, self-contained server environment that lives entirely on this USB/SSD drive. Plug it into any computer, run one command, and you have:

- **n8n** — Workflow automation (your workflows, credentials, executions)
- **PostgreSQL** — Persistent database
- **Redis** — Caching & queues
- **nginx** — Reverse proxy with HTTPS
- **Ollama** — Local LLMs (Llama, Mistral, CodeLlama, etc.)
- **Open WebUI** — Chat interface for local models
- **Flowise / Dify** — Visual AI agent builders
- **ChromaDB / Qdrant** — Vector databases for RAG
- **Adminer** — Database UI
- **Uptime Kuma** — Service monitoring
- **Data Workspace** — SQL + AI analysis, NL→SQL, charts
- **Security** — Encrypted secrets, firewall, HTTPS certs
- **Networking** — LAN access, reverse proxy, port scanner
- **Monitoring** — CPU/RAM/disk, uptime, resource limits
- **Backups/Clone** — One-click drive backup & migration
- **Profiles** — Multi-user, SSH key management
- **Tutorials** — 7 built-in guides

**All data stays on this drive.** Nothing is installed on the host machine except Docker.

---

## Quick Start

### 1. Plug In
Insert this USB/SSD into any computer:
- **Chromebook** (Crostini/Linux enabled)
- **Linux** (Ubuntu, Debian, Fedora, Arch, Alpine, etc.)
- **Windows** (WSL 2 + Docker Desktop)
- **macOS** (Docker Desktop)
- **Raspberry Pi / Mini PC** (headless server)

### 2. Share with Linux (Chromebook only)
1. Open **Files** app
2. Right-click this drive → **"Share with Linux"**
3. Note the mount path (e.g., `/media/removable/PALLADIUM`)

### 3. Run
```bash
# Find your mount path
ls /media/removable/   # Chromebook
ls /mnt/               # Linux
df -h                  # Any

# Enter the drive
cd /media/removable/PALLADIUM/palladium  # adjust path

# Make executable (first time only)
chmod +x palladium modules/*.sh

# Launch
./palladium
```

### 4. Install n8n (or any service)
```
→ Quick Start → Install a Service → n8n
→ Start n8n
→ Open http://localhost:5678
```

---

## Folder Structure

```
PALLADIUM/
├── palladium              # Main CLI (run this)
├── palladium.ps1          # Windows PowerShell launcher
├── palladium.bat          # Windows CMD launcher
├── install.sh             # One-line Linux/macOS/WSL installer
├── install.ps1            # One-line Windows installer
├── modules/               # 24 feature modules
├── services/              # Docker Compose files
├── stacks/                # Pre-built stacks (starter, dev, business, production)
├── marketplace/           # 8 one-click tools
└── data/                  # ← YOUR DATA LIVES HERE
    ├── installed/         # Service configurations
    ├── workspace/         # Databases, exports, queries
    ├── secrets/           # AES-256 encrypted credentials
    ├── profiles/          # User profiles, SSH keys
    ├── backups/           # Full drive backups (tar.gz)
    ├── logs/              # Service logs
    └── notify/            # Alert history
```

---

## Key Commands

| Command | Action |
|---------|--------|
| `./palladium` | Interactive menu |
| `palladium install n8n` | Install n8n |
| `palladium start n8n` | Start n8n |
| `palladium stop n8n` | Stop n8n |
| `palladium status` | Show all services |
| `palladium logs n8n` | View n8n logs |
| `palladium backup` | Backup all services |
| `palladium clone` | Clone drive to another USB |
| `palladium security` | Secrets, firewall, HTTPS |
| `palladium network` | LAN access, reverse proxy |
| `palladium monitor` | Live resource monitor |
| `palladium ai` | Ollama, API connectors, RAG |
| `palladium data` | SQL workspace, NL→SQL, charts |

---

## Why Portable?

| Benefit | Description |
|---------|-------------|
| **Zero Cloud Dependency** | Your data never leaves this drive |
| **Instant Migration** | Plug into new machine → run `./palladium` → identical environment |
| **Air-Gapped Ready** | Works completely offline |
| **Team Handoff** | Hand the drive to a colleague — they get exact same setup |
| **Disaster Recovery** | `palladium clone` to backup drive in minutes |
| **Cost Control** | Free software. One-time hardware cost. No subscriptions. |
| **Privacy** | Local LLMs (Ollama), local databases, local everything |
| **Always Yours** | No vendor lock-in. Standard Docker + open configs. |

---

## Requirements on Host Machine

| Platform | Needs |
|----------|-------|
| **Chromebook** | Chrome OS 91+, Crostini (Linux) enabled |
| **Linux** | Docker (`curl -fsSL get.docker.com \| sh`) |
| **Windows** | WSL 2 + Docker Desktop (WSL integration enabled) |
| **macOS** | Docker Desktop |
| **ARM (Pi)** | Docker (`curl -fsSL get.docker.com \| sh`) |

**First run** — Palladium's installer handles Docker auto-install on Linux.

---

## Backup & Recovery

```bash
# Full drive backup (to another drive or file)
palladium backup

# Clone to another USB/SSD
palladium clone → "Clone to Another Drive"

# Compare two drives
palladium clone → "Compare Drives"

# Restore from backup
palladium restore
```

---

## Security Notes

- **Secrets** encrypted with OpenSSL AES-256 (`palladium security → Secrets Manager`)
- **HTTPS** self-signed certs generated automatically (`palladium security → HTTPS Certs`)
- **Firewall** UFW rules managed (`palladium security → Firewall`)
- **Security scan** rates your setup 0-100 (`palladium security → Security Scan`)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Permission denied" | `chmod +x palladium modules/*.sh` |
| Docker not found | Run `./install.sh` (auto-installs) |
| Docker daemon not running | `sudo systemctl start docker` (Linux) / Open Docker Desktop (Win/Mac) |
| Port 5678 in use | `palladium network → Port Scanner` → change port in `palladium install n8n` |
| Chromebook can't see drive | Files app → right-click drive → "Share with Linux" |
| WSL can't access D: | `ls /mnt/d/` — if empty, enable WSL automount in `/etc/wsl.conf` |

---

## Support

- **Built-in help:** `palladium help` or `palladium tutorials`
- **Recovery advisor:** On any error, Palladium asks *what you want to do* — not just shows an error
- **GitHub:** https://github.com/M-2000-0/Palladium

---

## License

MIT — Free forever. Build your own. Sell hardware. No royalties.

---

**Made with ❤️ for the 300k users who want their server back.**

*Plug in. Power up. Host anything.*