# Palladium - Portable Server Manager

Plug in your SSD. Run `palladium`. Host anything.

## For Non-Technical Users

**One command. That's it.**

```bash
palladium
```

You'll see a friendly menu. Pick an option. Done.

## Quick Start (Recommended)

The fastest way to get running:

```bash
palladium
```

Then select **[1] Quick Start** and pick a stack:

| Stack | What's Inside | Best For |
|-------|--------------|----------|
| **Starter** | n8n + PostgreSQL | First-time users |
| **Business** | n8n + PostgreSQL + Redis | Automations at scale |
| **Dev** | Nginx + PostgreSQL + Redis | Web hosting |
| **Production** | PostgreSQL + Redis | databases + caching |

Everything installs automatically. No configuration needed.

## Installation

### One-Time Setup (Chromebook)

1. Plug in your SSD
2. Right-click SSD in Files app > "Share with Linux"
3. Open Linux terminal:
   ```bash
   cd /media/YOUR_SSD/palladium
   chmod +x install.sh
   ./install.sh
   ```
4. Done! Now just type `palladium` from anywhere.

### What install.sh Does
- Installs Docker (if missing)
- Adds `palladium` to your PATH
- Takes about 2 minutes

## Commands

| Command | What It Does |
|---------|-------------|
| `palladium` | Launch the interactive menu |
| `palladium stack` | Install a pre-built stack |
| `palladium start <name>` | Start a service |
| `palladium stop <name>` | Stop a service |
| `palladium status` | See what's running |
| `palladium logs <name>` | See what's happening |

## After Install

When you install a service:
- The browser opens automatically
- A QR code appears (scan with your phone!)
- You get the URL displayed

## Adding Custom Services

Drop a `.yml` file in the `services/` folder:

```yaml
# desc: My custom app
version: "3.8"
services:
  myapp:
    image: myapp:latest
    ports:
      - "${PORT}:8080"
```

## Folder Structure

```
palladium/
├── palladium          # The CLI command
├── install.sh         # One-time setup
├── modules/           # Core logic
├── services/          # Service templates
├── stacks/            # Pre-built stacks
└── data/              # Your installed services
```

## Troubleshooting

**"Docker not found"**
```bash
palladium
# Go to Settings > Install Docker
```

**Service won't start**
```bash
palladium logs service-name
```

**Port already in use**
Change the port during install, or edit the docker-compose.yml in `data/installed/your-service/`
