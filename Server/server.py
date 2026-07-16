#!/usr/bin/env python3
"""Server - Terminal app. Click the icon. Manage your server. Zero setup."""

import os, sys, json, shutil, platform, subprocess, time, webbrowser
from pathlib import Path
from datetime import datetime

try:
    from rich.console import Console
    from rich.layout import Layout
    from rich.live import Live
    from rich.panel import Panel
    from rich.table import Table
    from rich.text import Text
    from rich.prompt import Prompt, Confirm
    from rich.align import Align
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.columns import Columns
    from rich import box
    from rich.markdown import Markdown
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False


# ── Detect Palladium ────────────────────────────────────────────────

def find_palladium():
    candidates = [
        Path.cwd() / "palladium",
        Path.cwd().parent / "palladium",
        Path.home() / "palladium",
    ]
    for p in (Path.cwd(), Path(__file__).resolve().parent.parent):
        c = p / "palladium" / "palladium"
        if c.exists(): return (p / "palladium").resolve()
    for c in candidates:
        if c.exists(): return c.resolve()
    return None


def discover_services(palladium_home):
    d = palladium_home / "data" / "installed"
    services = []
    if not d.exists(): return services
    for svc in d.iterdir():
        if not svc.is_dir(): continue
        name = svc.name
        port = (svc / ".port").read_text().strip() if (svc / ".port").exists() else ""
        meta = {}
        if (svc / ".meta").exists():
            for line in (svc / ".meta").read_text().splitlines():
                if "=" in line:
                    k, v = line.split("=", 1); meta[k] = v
        running = False
        try:
            r = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=5)
            running = name in r.stdout.splitlines()
        except: pass
        services.append({"name": name, "type": meta.get("service", "custom"), "port": port, "running": running, "url": f"http://localhost:{port}" if port else ""})
    return services


def check_docker():
    try: return subprocess.run(["docker", "info"], capture_output=True, timeout=5).returncode == 0
    except: return False


def get_docker_installed():
    try: return subprocess.run(["docker", "--version"], capture_output=True, timeout=5).returncode == 0
    except: return False


# ── Rich Terminal App ───────────────────────────────────────────────

console = Console()


def show_logo():
    return Panel(Align.center(Text("""
  ███████  ███████  ██████  ██    ██  ███████  ██████  ██████
  ██       ██       ██   ██ ██    ██ ██       ██   ██ ██   ██
  ███████  █████    ██████  ██    ██ █████    ██████  ██████
       ██  ██       ██   ██  ██  ██  ██       ██   ██ ██
  ███████  ███████  ██   ██   ████   ███████  ██   ██ ██
""", style="bold white")), border_style="dim", padding=(0,0))


def show_help():
    console.clear()
    console.print(show_logo())
    console.print("""
  [bold]Server[/] — Self-host your own services. No cloud fees.

  [bold white]Quick start:[/]
    1. Pick a service from the menu below
    2. Server installs it for you
    3. Open it from your browser

  [bold white]What you can host:[/]
    [green]n8n[/]       — Workflow automation (connect apps together)
    [green]PostgreSQL[/] — Store data for your apps
    [green]Ollama[/]     — Run AI models locally (like ChatGPT on your own computer)
    [green]n8n + DB[/]  — Starter stack (most popular)

  [dim]Press any key to go back.[/]""")
    try:
        import msvcrt; msvcrt.getch()
    except ImportError:
        input()


API_KEY_NAMES = [
    ("OPENAI_API_KEY", "OpenAI"),
    ("ANTHROPIC_API_KEY", "Anthropic"),
    ("GROQ_API_KEY", "Groq"),
    ("COHERE_API_KEY", "Cohere"),
    ("MISTRAL_API_KEY", "Mistral"),
    ("HUGGINGFACE_API_KEY", "HuggingFace"),
    ("AZURE_OPENAI_API_KEY", "Azure OpenAI"),
    ("AZURE_OPENAI_ENDPOINT", "Azure Endpoint"),
    ("PINECONE_API_KEY", "Pinecone"),
    ("QDRANT_API_KEY", "Qdrant"),
    ("SUPABASE_URL", "Supabase URL"),
    ("SUPABASE_SERVICE_KEY", "Supabase Service Key"),
]


def get_api_keys_file(palladium_home):
    return palladium_home / "data" / ".api_keys"


def load_api_keys(palladium_home):
    f = get_api_keys_file(palladium_home)
    keys = {}
    if f.exists():
        for line in f.read_text().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                keys[k] = v
    return keys


def save_api_keys(palladium_home, keys):
    f = get_api_keys_file(palladium_home)
    f.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{k}={v}" for k, v in keys.items() if v.strip()]
    f.write_text("\n".join(lines) + "\n")
    f.chmod(0o600)
    # Windows: restrict file to current user via icacls
    if platform.system() == "Windows":
        user = os.environ.get("USERNAME", "")
        if user:
            subprocess.run(
                ["icacls", str(f), "/inheritance:r", "/grant", f"{user}:F"],
                capture_output=True, timeout=5,
            )


CONFIG_FILE = "data/.server-config"

def get_config_file(palladium_home):
    return palladium_home / CONFIG_FILE

def load_config(palladium_home):
    cfg = {}
    f = get_config_file(palladium_home)
    if f.exists():
        for line in f.read_text().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg

def save_config(palladium_home, cfg):
    f = get_config_file(palladium_home)
    f.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{k}={v}" for k, v in cfg.items()]
    f.write_text("\n".join(lines) + "\n")

def setup_wizard(palladium_home):
    """First-run setup wizard — runs once, then saved to .server-config."""
    console.clear()
    console.print(show_logo())
    console.print("\n  [bold white]Welcome! Let's set up your server.[/]\n")
    console.print("  How do you want to start?\n")

    catalog = [
        ("Full auto", "Install services + enter API keys + set passwords. USB plug = silent background."),
        ("API keys + preferences", "Enter API keys now. Install services later from the menu."),
        ("Full config wizard", "Walk through everything step by step, then show the dashboard."),
    ]
    for i, (title, desc) in enumerate(catalog):
        console.print(f"  [bold white]{i+1}[/]  {title}")
        console.print(f"      [dim]{desc}[/]\n")

    ch = Prompt.ask("  Choose", choices=["1", "2", "3"], default="1")
    setup_mode = int(ch)

    cfg = {"setup_mode": ch, "autorun_mode": "tui"}

    # Always prompt for API keys
    has_keys = load_api_keys(palladium_home)
    if not has_keys:
        console.print("\n  [bold]Let's add your API keys.[/]  [dim](Skip any you don't need)[/]")
        keys = {}
        for var_name, label in API_KEY_NAMES:
            val = Prompt.ask(f"  {label} key (optional)", password=True, default="")
            if val:
                keys[var_name] = val
        if keys:
            save_api_keys(palladium_home, keys)
            cfg["api_keys_configured"] = "true"

    if setup_mode == 1:
        # Full auto: install default services, go background
        console.print("\n  [bold]Installing starter services...[/]")
        services_to_install = ["n8n", "postgres"]
        for name in services_to_install:
            console.print(f"  [yellow]Installing {name}...[/]")
            console.print(f"  [dim]Follow the prompts in the Palladium wizard.[/]\n")
            subprocess.run([str(palladium_home / "palladium"), "launch", name],
                           timeout=300)
            console.print(f"  [green]{name} finished.[/]")
        cfg["autorun_mode"] = "background"
        console.print("\n  [green]All set! On USB plug-in, your server starts silently.[/]")

    elif setup_mode == 2:
        # API keys + preferences: done, show TUI
        console.print("\n  [green]API keys saved. Install services anytime from the menu.[/]")

    elif setup_mode == 3:
        # Full config: ask about autorun preference
        pass

    # Ask autorun preference (for modes 2 and 3, or let mode 3 override)
    if setup_mode in (2, 3):
        console.print("\n  [bold]When you plug in the USB:[/]\n")
        console.print("  [1] Show the dashboard (you see the menu)")
        console.print("  [2] Run in background (services start silently)\n")
        ar = Prompt.ask("  Choose", choices=["1", "2"], default="1")
        cfg["autorun_mode"] = "background" if ar == "2" else "tui"

    save_config(palladium_home, cfg)
    console.print(f"\n  [green]Setup complete![/]")
    time.sleep(1)


def manage_api_keys(palladium_home):
    keys = load_api_keys(palladium_home)
    while True:
        console.clear()
        console.print(show_logo())
        console.print("\n  [bold white]Manage API Keys[/]\n")
        console.print("  These are shared across all services (n8n, etc.).\n")
        for i, (var_name, label) in enumerate(API_KEY_NAMES):
            val = keys.get(var_name, "")
            if val:
                masked = val[:4] + "*" * min(len(val) - 4, 16)
                display = f"[green]{masked}[/]"
            else:
                display = "[dim]not set[/]"
            console.print(f"  [bold white]{i+1}[/]  {label:20} {display}")
        console.print(f"  [bold white]A[/]  Add / edit a key")
        console.print(f"  [bold white]R[/]  Remove a key")
        console.print(f"  [bold white]0[/]  Back\n")
        ch = Prompt.ask("  Choose", choices=[str(i+1) for i in range(len(API_KEY_NAMES))] + ["a", "r", "0"], default="0")
        if ch == "0":
            return
        elif ch.lower() == "a":
            console.print("\n  [bold]Available keys:[/]")
            for i, (var_name, label) in enumerate(API_KEY_NAMES):
                current = keys.get(var_name, "")
                display = f"[dim]({current[:4]}****)[/] " if current else ""
                console.print(f"  [{i+1}] {label:20} {display}[dim]{var_name}[/]")
            idx = Prompt.ask("  Which key", choices=[str(i+1) for i in range(len(API_KEY_NAMES))], default="1")
            var_name, label = API_KEY_NAMES[int(idx) - 1]
            old = keys.get(var_name, "")
            val = Prompt.ask(f"  Enter {label} key", password=True, default=old)
            if val:
                keys[var_name] = val
                save_api_keys(palladium_home, keys)
                console.print(f"  [green]{label} key saved.[/]")
            else:
                console.print("  [yellow]Skipped.[/]")
            time.sleep(1)
        elif ch.lower() == "r":
            set_keys = [(var_name, label) for var_name, label in API_KEY_NAMES if var_name in keys]
            if not set_keys:
                console.print("  [yellow]No keys to remove.[/]")
                time.sleep(1)
                continue
            console.print("\n  [bold]Remove a key:[/]")
            for i, (var_name, label) in enumerate(set_keys):
                console.print(f"  [{i+1}] {label}")
            idx = Prompt.ask("  Which to remove", choices=[str(i+1) for i in range(len(set_keys))], default="1")
            var_name, label = set_keys[int(idx) - 1]
            del keys[var_name]
            save_api_keys(palladium_home, keys)
            console.print(f"  [green]{label} key removed.[/]")
            time.sleep(1)


def build_status_bar(docker_ok, services):
    running = sum(1 for s in services if s["running"])
    t = Text()
    t.append(" Docker:", style="bold")
    t.append(" Running " if docker_ok else " Not running ", style="green" if docker_ok else "red")
    t.append(" | Services:", style="bold")
    t.append(f" {running}/{len(services)} ", style="bold")
    if running == len(services) and services:
        t.append("All good!", style="green")
    elif services:
        t.append(f"({running - len(services)} stopped)", style="yellow")
    else:
        t.append("None installed", style="dim")
    t.append(f" | {datetime.now():%H:%M}", style="dim")
    return Panel(t, border_style="dim", padding=(0,1))


def build_service_list(services, selected=0):
    if not services:
        return Panel("  [yellow]No services hosted yet.[/]\n  Pick one from the menu below and install it.", title="Your Services", border_style="dim", box=box.ROUNDED)
    table = Table(box=box.SIMPLE, header_style="bold white", show_header=False)
    table.add_column("", width=2)
    table.add_column("Service", width=18)
    table.add_column("Status", width=10)
    table.add_column("Access", width=30)
    for i, s in enumerate(services):
        marker = "[bold white]>[/]" if i == selected else " "
        dot = "[green]●[/]" if s["running"] else "[red]○[/]"
        status = "Running" if s["running"] else "Stopped"
        table.add_row(f"{marker} {dot}", s["name"], status, s["url"] or "—")
    return Panel(table, title="Your Services", border_style="dim", box=box.ROUNDED)


def build_menu(selected=0):
    items = [
        ("Install a service", "Pick from the catalog"),
        ("Open in browser", "Open a running service"),
        ("Web view (LAN)", "Access from your phone"),
        ("API Keys", "Add OpenAI, Anthropic, etc."),
        ("Help", "What can I host?"),
        ("Quit", "Stop the server"),
    ]
    table = Table(box=box.SIMPLE, show_header=False)
    table.add_column("", width=2)
    table.add_column("Action", width=24)
    table.add_column("Description", width=30, style="dim")
    for i, (action, desc) in enumerate(items):
        marker = "[bold white]>[/]" if i == selected else " "
        table.add_row(f"{marker}", f"[bold]{action}[/]", desc)
    return Panel(table, title="Menu", border_style="dim", box=box.ROUNDED)


def build_system_panel(docker_ok):
    t = Text()
    docker_status = "[green]● Running[/]" if docker_ok else "[red]○ Not running[/]"
    t.append(f"Docker     {docker_status}\n", style="bold")
    if HAS_PSUTIL:
        mem = psutil.virtual_memory()
        bar = "█" * max(1, int(mem.percent/5)) + "░" * (20 - max(1, int(mem.percent/5)))
        t.append(f"Memory     {bar} {mem.percent:.0f}%\n", style="white")
        du = shutil.disk_usage("/")
        pct = du.used / du.total * 100
        bar = "█" * max(1, int(pct/5)) + "░" * (20 - max(1, int(pct/5)))
        t.append(f"Disk       {bar} {pct:.0f}% ({du.free/1024**3:.1f}G free)\n", style="white")
    t.append(f"Host       {platform.node()}", style="dim")
    return Panel(t, title="System", border_style="dim", box=box.ROUNDED)


def background_start(palladium_home):
    """Start Docker + all installed services, no TUI."""
    if not check_docker() and get_docker_installed():
        subprocess.run(["docker", "desktop", "start"], capture_output=True, timeout=15)
        time.sleep(3)
    installed = palladium_home / "data" / "installed"
    if installed.exists():
        for svc in installed.iterdir():
            if svc.is_dir():
                name = svc.name
                subprocess.run(
                    ["docker", "compose", "up", "-d"],
                    cwd=str(svc), capture_output=True, timeout=30,
                )
    console.print("[dim]Server started in background mode.[/]")
    sys.exit(0)


def show_main(palladium_home, cfg):
    """Main loop — arrow key menu, live dashboard."""
    menu_idx = 0
    svc_idx = 0

    while True:
        docker_ok = check_docker()
        services = discover_services(palladium_home)

        layout = Layout()
        layout.split(
            Layout(name="header", size=7),
            Layout(name="body"),
            Layout(name="footer", size=3),
        )
        layout["body"].split_row(
            Layout(name="left", ratio=2),
            Layout(name="right", ratio=1),
        )
        layout["left"].split(
            Layout(name="services"),
            Layout(name="menu", size=10),
        )

        header = show_logo()
        if not cfg.get("docker_started"):
            cfg["docker_started"] = "true"
            if not docker_ok and get_docker_installed():
                subprocess.run(["docker", "desktop", "start"], capture_output=True, timeout=10)

        layout["header"].update(header)
        layout["services"].update(build_service_list(services, svc_idx))
        layout["menu"].update(build_menu(menu_idx))
        layout["right"].update(build_system_panel(docker_ok))
        layout["footer"].update(build_status_bar(docker_ok, services))

        console.clear()
        console.print(layout)

        # Simple number-based interaction (no arrow keys needed)
        action = Prompt.ask("  Choose", choices=["1","2","3","4","5","6","h"], default="1")

        if action == "1":  # Install
            install_menu(palladium_home)
        elif action == "2":  # Open browser
            running = [s for s in services if s["running"]]
            if not running:
                console.print("[yellow]No running services. Install one first.[/]")
                time.sleep(1.5)
                continue
            console.print("\n  [bold]Running services:[/]")
            for i, s in enumerate(running):
                console.print(f"  [{i+1}] {s['name']}  [dim]{s['url']}[/]")
            ch = Prompt.ask("  Open", choices=[str(i+1) for i in range(len(running))], default="1")
            webbrowser.open(running[int(ch)-1]["url"])
        elif action == "3":  # Web view
            subprocess.Popen([sys.executable, __file__, "web"])
            time.sleep(2)
            webbrowser.open("http://localhost:9090")
        elif action == "4":  # API Keys
            manage_api_keys(palladium_home)
        elif action == "5":  # Help
            show_help()
        elif action in ("6", "q"):  # Quit
            console.print("[green]Server stopped.[/]")
            break


def install_menu(palladium_home):
    catalog = [
        ("n8n", "Workflow automation — connect apps without code", "recommended"),
        ("postgres", "PostgreSQL database — store your data", ""),
        ("ollama", "AI chat (Llama, Mistral) — run locally", ""),
        ("redis", "Redis cache — speed up your apps", ""),
        ("nginx", "Web server — host websites", ""),
    ]
    while True:
        console.clear()
        console.print(show_logo())
        console.print("\n  [bold]Install a service[/]\n")
        for i, (name, desc, tag) in enumerate(catalog):
            badge = f" [green]{tag}[/]" if tag else ""
            console.print(f"  [bold white]{i+1}[/]  {name}{badge}")
            console.print(f"      {desc}")
        console.print(f"  [bold white]0[/]  Back\n")
        ch = Prompt.ask("  Choose", choices=[str(i+1) for i in range(len(catalog))] + ["0"], default="1")
        if ch == "0": return
        name = catalog[int(ch)-1][0]
        console.print(f"  [yellow]Installing {name}...[/]")
        console.print(f"  [dim]Follow the prompts in the Palladium wizard.[/]\n")
        subprocess.run([str(palladium_home / "palladium"), "launch", name], timeout=300)
        console.print(f"\n  [green]{name} installed![/]")
        time.sleep(1)
        return


# ── Web view (secondary) ────────────────────────────────────────────

def run_web(port=9090):
    from http.server import HTTPServer, BaseHTTPRequestHandler
    palladium_home = find_palladium()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/services":
                s = discover_services(palladium_home) if palladium_home else []
                self._json(s)
            elif self.path == "/api/system":
                self._json({"docker": check_docker(), "hostname": platform.node()})
            else:
                self._html()
        def _json(self, data):
            self.send_response(200); self.send_header("Content-Type","application/json"); self.send_header("Access-Control-Allow-Origin","*"); self.end_headers(); self.wfile.write(json.dumps(data).encode())
        def _html(self):
            s = discover_services(palladium_home) if palladium_home else []
            d = check_docker(); r = sum(1 for x in s if x["running"])
            cards = "".join(f'<div class="card" onclick="window.open(\'{x["url"]}\',\'_blank\')"><div class="name"><span class="dot" style="background:{"#22c55e" if x["running"] else "#64748b"}"></span>{x["name"]}</div><div class="url">{x["url"] or "—"}</div></div>' for x in s)
            self.send_response(200); self.send_header("Content-Type","text/html;charset=utf-8"); self.end_headers()
            self.wfile.write(f"""<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Server</title><style>*{{margin:0;padding:0;box-sizing:border-box}}body{{font-family:-apple-system,sans-serif;background:#0f172a;color:#e2e8f0;padding:2rem}}h1{{font-size:1.5rem;margin-bottom:0.25rem;color:#38bdf8}}p{{color:#64748b;margin-bottom:1.5rem}}.stats{{display:flex;gap:.75rem;margin-bottom:1.5rem}}.stat{{background:#1e293b;padding:.75rem 1.25rem;border-radius:8px;flex:1}}.stat-label{{font-size:.7rem;color:#475569;text-transform:uppercase}}.stat-value{{font-size:1.25rem;font-weight:700}}.card{{background:#1e293b;border-radius:8px;padding:.75rem 1rem;cursor:pointer;transition:all .15s;margin-bottom:.5rem}}.card:hover{{background:#334155}}.name{{display:flex;align-items:center;gap:.5rem;font-weight:600}}.dot{{width:8px;height:8px;border-radius:50%}}.url{{font-size:.8rem;color:#38bdf8;font-family:monospace;margin-top:.25rem;margin-left:1rem}}</style></head><body><h1>Server</h1><p>Self-hosted on {platform.node()}</p><div class="stats"><div class="stat"><div class="stat-label">Services</div><div class="stat-value">{r}/{len(s)}</div></div><div class="stat"><div class="stat-label">Docker</div><div class="stat-value">{'Running' if d else 'Stopped'}</div></div></div><div id="grid">{cards or '<p style="color:#475569">No services yet.</p>'}</div><script>setInterval(async()=>{{let s=await(await fetch('/api/services')).json(),d=await(await fetch('/api/system')).json();document.querySelector('.stat-value').textContent=s.filter(x=>x.running).length+'/'+s.length;}},5000)</script></body></html>""".encode())
        def log_message(self,*a): pass

    svr = HTTPServer(("0.0.0.0", port), Handler)
    try: svr.serve_forever()
    except KeyboardInterrupt: pass


# ── Entry Point ─────────────────────────────────────────────────────

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("command", nargs="?", default="start")
    parser.add_argument("--port", type=int, default=9090)
    args = parser.parse_args()

    if not HAS_RICH:
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "rich", "psutil"])
        print("Installed. Restart the app."); sys.exit(0)

    ph = find_palladium()
    if not ph:
        console.print("[red]Server must run from a Palladium installation.[/]"); sys.exit(1)

    if args.command == "web":
        run_web(port=args.port)
    elif args.command == "bg":
        # Background mode: start Docker + all installed services, no TUI
        background_start(ph)
    else:
        cfg = load_config(ph)
        first_run = not cfg
        if first_run:
            setup_wizard(ph)
            cfg = load_config(ph)
        show_main(ph, cfg)


if __name__ == "__main__":
    main()
