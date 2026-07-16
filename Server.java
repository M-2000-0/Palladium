import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.time.*;
import java.time.format.*;
import java.util.stream.*;
import java.util.function.*;

public class Server {
    static final String SILVER = "\033[1;37m";
    static final String BOLD = "\033[1m";
    static final String DIM = "\033[2m";
    static final String GREEN = "\033[0;32m";
    static final String RED = "\033[0;31m";
    static final String YELLOW = "\033[1;33m";
    static final String NC = "\033[0m";

    static Path palladiumHome;
    static final Scanner stdin = new Scanner(System.in);

    // ── API key registry ──
    static final String[][] API_KEY_NAMES = {
        {"OPENAI_API_KEY", "OpenAI"},
        {"ANTHROPIC_API_KEY", "Anthropic"},
        {"GROQ_API_KEY", "Groq"},
        {"COHERE_API_KEY", "Cohere"},
        {"MISTRAL_API_KEY", "Mistral"},
        {"HUGGINGFACE_API_KEY", "HuggingFace"},
        {"AZURE_OPENAI_API_KEY", "Azure OpenAI"},
        {"AZURE_OPENAI_ENDPOINT", "Azure Endpoint"},
        {"PINECONE_API_KEY", "Pinecone"},
        {"QDRANT_API_KEY", "Qdrant"},
        {"SUPABASE_URL", "Supabase URL"},
        {"SUPABASE_SERVICE_KEY", "Supabase Service Key"},
    };

    // ── Path resolution ──

    static Path findPalladium() {
        String[] candidates = {
            "palladium",
            "../palladium",
            System.getProperty("user.home") + "/palladium",
        };
        Path cwd = Paths.get("").toAbsolutePath();
        Path here = cwd.resolve("palladium/palladium");
        if (Files.exists(here)) return cwd.resolve("palladium");
        Path parent = cwd.getParent();
        if (parent != null) {
            Path p = parent.resolve("palladium/palladium");
            if (Files.exists(p)) return parent.resolve("palladium");
        }
        for (String s : candidates) {
            Path p = Paths.get(s).normalize().toAbsolutePath();
            Path test = p.resolve("palladium");
            if (Files.exists(test)) return p;
            if (Files.exists(p)) return p;
        }
        return null;
    }

    // ── Service model ──

    static class Service {
        String name, type, port, url;
        boolean running;
        Service(String name, String type, String port, boolean running) {
            this.name = name; this.type = type; this.port = port;
            this.url = port.isEmpty() ? "" : "http://localhost:" + port;
            this.running = running;
        }
    }

    static List<Service> discoverServices(Path ph) {
        List<Service> list = new ArrayList<>();
        Path dir = ph.resolve("data/installed");
        if (!Files.isDirectory(dir)) return list;
        try {
            Set<String> running = new HashSet<>();
            try {
                Process p = new ProcessBuilder("docker", "ps", "--format", "{{.Names}}")
                    .redirectErrorStream(true).start();
                try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                    String l; while ((l = r.readLine()) != null) running.add(l.trim());
                }
                p.waitFor();
            } catch (Exception ignored) {}

            try (Stream<Path> entries = Files.list(dir)) {
                entries.filter(Files::isDirectory).forEach(svc -> {
                    String name = svc.getFileName().toString();
                    String port = "";
                    Path pf = svc.resolve(".port");
                    if (Files.exists(pf)) try { port = new String(Files.readAllBytes(pf)).trim(); } catch (Exception ignored) {}
                    String type = "custom";
                    Path mf = svc.resolve(".meta");
                    if (Files.exists(mf)) try {
                        for (String line : new String(Files.readAllBytes(mf)).split("\n")) {
                            if (line.startsWith("service=")) type = line.substring(8).trim();
                        }
                    } catch (Exception ignored) {}
                    boolean run = running.contains(name);
                    list.add(new Service(name, type, port, run));
                });
            }
        } catch (Exception ignored) {}
        return list;
    }

    // ── Docker helpers ──

    static boolean checkDocker() {
        try {
            Process p = new ProcessBuilder("docker", "info").start();
            return p.waitFor() == 0;
        } catch (Exception e) { return false; }
    }

    static boolean getDockerInstalled() {
        try {
            Process p = new ProcessBuilder("docker", "--version").start();
            return p.waitFor() == 0;
        } catch (Exception e) { return false; }
    }

    // ── API key helpers ──

    static Path apiKeysFile(Path ph) { return ph.resolve("data/.api_keys"); }

    static Map<String,String> loadAPIKeys(Path ph) {
        Map<String,String> map = new LinkedHashMap<>();
        Path f = apiKeysFile(ph);
        if (Files.exists(f)) try {
            for (String line : Files.readAllLines(f)) {
                int eq = line.indexOf('=');
                if (eq > 0) map.put(line.substring(0, eq), line.substring(eq + 1));
            }
        } catch (Exception ignored) {}
        return map;
    }

    static void saveAPIKeys(Path ph, Map<String,String> keys) {
        try {
            Path f = apiKeysFile(ph);
            Files.createDirectories(f.getParent());
            StringBuilder sb = new StringBuilder();
            for (Map.Entry<String,String> e : keys.entrySet()) {
                if (!e.getValue().trim().isEmpty())
                    sb.append(e.getKey()).append('=').append(e.getValue()).append('\n');
            }
            Files.write(f, sb.toString().getBytes());
            f.toFile().setReadable(true, true);
            f.toFile().setWritable(true, true);
        } catch (Exception ignored) {}
    }

    // ── UI helpers ──

    static void clear() { System.out.print("\033[H\033[2J"); System.out.flush(); }

    static String mask(String val) {
        if (val == null || val.length() < 4) return "****";
        int n = Math.min(val.length() - 4, 16);
        StringBuilder sb = new StringBuilder(val.substring(0, 4));
        for (int i = 0; i < n; i++) sb.append('*');
        return sb.toString();
    }

    static void pause() {
        System.out.print("\n  Press Enter to go back...");
        stdin.nextLine();
    }

    static void header() {
        System.out.print(SILVER + BOLD);
        System.out.println("  ███████  ███████  ██████  ██    ██  ███████  ██████  ██████");
        System.out.println("  ██       ██       ██   ██ ██    ██ ██       ██   ██ ██   ██");
        System.out.println("  ███████  █████    ██████  ██    ██ █████    ██████  ██████");
        System.out.println("       ██  ██       ██   ██  ██  ██  ██       ██   ██ ██");
        System.out.println("  ███████  ███████  ██   ██   ████   ███████  ██   ██ ██");
        System.out.print(NC);
        System.out.println("  " + DIM + "Self-host. Your way." + NC);
        System.out.println();
    }

    static void showHelp() {
        clear(); header();
        System.out.println("  " + BOLD + "Server" + NC + " — Self-host your own services. No cloud fees.\n");
        System.out.println("  " + SILVER + BOLD + "Quick start:" + NC);
        System.out.println("    1. Pick a service from the menu below");
        System.out.println("    2. Server installs it for you");
        System.out.println("    3. Open it from your browser\n");
        System.out.println("  " + SILVER + BOLD + "What you can host:" + NC);
        System.out.println("    " + GREEN + "n8n" + NC + "       — Workflow automation (connect apps together)");
        System.out.println("    " + GREEN + "PostgreSQL" + NC + " — Store data for your apps");
        System.out.println("    " + GREEN + "Ollama" + NC + "     — Run AI models locally");
        System.out.println("    " + GREEN + "Redis" + NC + "      — Cache & message broker\n");
        System.out.println("  " + DIM + "Press Enter to go back." + NC);
        stdin.nextLine();
    }

    // ── Main screen ──

    static void showMain() {
        boolean firstRun = !Files.exists(palladiumHome.resolve("data/.server-ready"));
        if (firstRun) try {
            Files.createDirectories(palladiumHome.resolve("data"));
            Files.createFile(palladiumHome.resolve("data/.server-ready"));
        } catch (Exception ignored) {}

        while (true) {
            boolean dockerOk = checkDocker();
            List<Service> services = discoverServices(palladiumHome);

            if (firstRun) {
                firstRun = false;
                if (!dockerOk && getDockerInstalled()) {
                    try { new ProcessBuilder("docker", "desktop", "start").start(); } catch (Exception ignored) {}
                }
            }

            clear();
            header();

            // ── Left column: services ──
            long running = services.stream().filter(s -> s.running).count();
            if (services.isEmpty()) {
                System.out.println("  " + YELLOW + "No services hosted yet." + NC);
                System.out.println("  Pick one from the menu below and install it.\n");
            } else {
                System.out.println("  " + SILVER + BOLD + "Your Services" + NC);
                System.out.println("  " + DIM + "  NAME                 STATUS    ACCESS" + NC);
                for (Service s : services) {
                    String dot = s.running ? GREEN + "\u25CF" : RED + "\u25CB";
                    String status = s.running ? "Running" : "Stopped";
                    System.out.printf("  %s %-20s %-9s %s" + NC + "%n",
                        dot, s.name, status, s.url.isEmpty() ? "\u2014" : s.url);
                }
                System.out.println();
            }

            // ── Menu ──
            System.out.println("  " + SILVER + BOLD + "Menu" + NC);
            System.out.println("  " + DIM + "  1  Install a service" + NC);
            System.out.println("  " + DIM + "  2  Open in browser" + NC);
            System.out.println("  " + DIM + "  3  API Keys" + NC);
            System.out.println("  " + DIM + "  4  Help" + NC);
            System.out.println("  " + DIM + "  5  Quit" + NC);
            System.out.println();

            // ── Right column: system info ──
            String dockerStatus = dockerOk ? GREEN + "\u25CF Running" : RED + "\u25CB Not running";
            System.out.println("  " + SILVER + BOLD + "System" + NC);
            System.out.println("  Docker     " + dockerStatus + NC);
            try {
                File root = new File("/");
                long total = root.getTotalSpace();
                long free = root.getFreeSpace();
                int pct = (int)((total - free) * 100 / total);
                String bar = String.join("", Collections.nCopies(Math.min(pct / 5, 20), "\u2588"))
                    + String.join("", Collections.nCopies(Math.min(20 - Math.min(pct / 5, 20), 20), "\u2591"));
                System.out.println("  Disk       " + SILVER + bar + " " + pct + "%" + NC + DIM + " (" + (free / (1024*1024*1024)) + "G free)" + NC);
            } catch (Exception ignored) {}
            System.out.println("  Host       " + DIM + System.getProperty("user.name") + NC);
            System.out.println();

            // ── Status bar ──
            String allOk = (running == services.size() && !services.isEmpty()) ? GREEN + "All good!" : (services.isEmpty() ? DIM + "None installed" : YELLOW + (services.size() - running) + " stopped");
            String statusLine = String.format("  " + BOLD + " Docker:" + NC + " %s  |  " + BOLD + "Services:" + NC + " %d/%d  %s  |  " + DIM + "%s" + NC,
                dockerOk ? GREEN + "Running" : RED + "Not running",
                running, services.size(), allOk,
                LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm")));
            System.out.println(statusLine);
            System.out.println();

            // ── Prompt ──
            System.out.print("  Choose (1-5): ");
            String choice = stdin.nextLine().trim();

            if (choice.equals("1")) {
                installMenu();
            } else if (choice.equals("2")) {
                List<Service> run = services.stream().filter(s -> s.running).collect(Collectors.toList());
                if (run.isEmpty()) {
                    System.out.println("  " + YELLOW + "No running services. Install one first." + NC);
                    pause();
                } else {
                    System.out.println("  " + BOLD + "Running services:" + NC);
                    for (int i = 0; i < run.size(); i++)
                        System.out.println("  [" + (i+1) + "] " + run.get(i).name + "  " + DIM + run.get(i).url + NC);
                    System.out.print("  Open: ");
                    String ch = stdin.nextLine().trim();
                    try {
                        int idx = Integer.parseInt(ch) - 1;
                        if (idx >= 0 && idx < run.size()) openBrowser(run.get(idx).url);
                    } catch (NumberFormatException ignored) {}
                }
            } else if (choice.equals("3")) {
                manageAPIKeys();
            } else if (choice.equals("4")) {
                showHelp();
            } else if (choice.equals("5")) {
                System.out.println("  " + GREEN + "Server stopped." + NC);
                return;
            }
        }
    }

    static void openBrowser(String url) {
        String os = System.getProperty("os.name").toLowerCase();
        try {
            if (os.contains("win"))
                new ProcessBuilder("cmd", "/c", "start", url).start();
            else if (os.contains("mac"))
                new ProcessBuilder("open", url).start();
            else
                new ProcessBuilder("xdg-open", url).start();
        } catch (Exception ignored) {}
    }

    // ── Install menu ──

    static void installMenu() {
        String[][] catalog = {
            {"n8n",     "Workflow automation \u2014 connect apps without code"},
            {"postgres","PostgreSQL database \u2014 store your data"},
            {"ollama",  "AI chat (Llama, Mistral) \u2014 run locally"},
            {"redis",   "Redis cache \u2014 speed up your apps"},
            {"nginx",   "Web server \u2014 host websites"},
        };

        while (true) {
            clear(); header();
            System.out.println("  " + BOLD + "Install a service" + NC + "\n");
            for (int i = 0; i < catalog.length; i++) {
                String badge = i == 0 ? " " + GREEN + "recommended" + NC : "";
                System.out.println("  " + SILVER + BOLD + (i+1) + NC + "  " + catalog[i][0] + badge);
                System.out.println("      " + DIM + catalog[i][1] + NC);
            }
            System.out.println("  " + SILVER + BOLD + "0" + NC + "  Back\n");
            System.out.print("  Choose: ");
            String ch = stdin.nextLine().trim();
            if (ch.equals("0")) return;
            try {
                int idx = Integer.parseInt(ch) - 1;
                if (idx >= 0 && idx < catalog.length) {
                    String name = catalog[idx][0];
                    System.out.println("  " + YELLOW + "Installing " + name + "...\n" + NC);
                    ProcessBuilder pb = new ProcessBuilder(
                        palladiumHome.resolve("palladium").toString(), "launch", name);
                    pb.inheritIO();
                    Process p = pb.start();
                    p.waitFor();
                    System.out.println("\n  " + GREEN + name + " installed!" + NC);
                    pause();
                    return;
                }
            } catch (Exception ignored) {}
        }
    }

    // ── API Keys screen ──

    static void manageAPIKeys() {
        Map<String,String> keys = loadAPIKeys(palladiumHome);
        while (true) {
            clear(); header();
            System.out.println("  " + SILVER + BOLD + "Manage API Keys" + NC + "\n");
            System.out.println("  These are shared across all services (n8n, etc.).\n");
            int i = 0;
            for (String[] pair : API_KEY_NAMES) {
                String val = keys.getOrDefault(pair[0], "");
                String display = val.isEmpty() ? DIM + "not set" : GREEN + mask(val);
                System.out.printf("  " + SILVER + BOLD + "%d" + NC + "  %-20s %s" + NC + "%n", ++i, pair[1], display);
            }
            System.out.println("  " + SILVER + BOLD + "A" + NC + "  Add / edit a key");
            System.out.println("  " + SILVER + BOLD + "R" + NC + "  Remove a key");
            System.out.println("  " + SILVER + BOLD + "0" + NC + "  Back\n");
            System.out.print("  Choose: ");
            String ch = stdin.nextLine().trim().toLowerCase();

            if (ch.equals("0")) return;
            else if (ch.equals("a")) {
                System.out.println("  " + BOLD + "Available keys:" + NC);
                for (int j = 0; j < API_KEY_NAMES.length; j++) {
                    String cur = keys.getOrDefault(API_KEY_NAMES[j][0], "");
                    String show = cur.isEmpty() ? "" : DIM + " (" + cur.substring(0, Math.min(4, cur.length())) + "****)" + NC + " ";
                    System.out.println("  [" + (j+1) + "] " + API_KEY_NAMES[j][1] + " " + show + DIM + API_KEY_NAMES[j][0] + NC);
                }
                System.out.print("  Which key: ");
                String idxStr = stdin.nextLine().trim();
                try {
                    int idx = Integer.parseInt(idxStr) - 1;
                    if (idx >= 0 && idx < API_KEY_NAMES.length) {
                        String varName = API_KEY_NAMES[idx][0];
                        String label = API_KEY_NAMES[idx][1];
                        String old = keys.getOrDefault(varName, "");
                        System.out.print("  Enter " + label + " key" + (old.isEmpty() ? ": " : " (Enter to keep " + mask(old) + "): "));
                        String val = stdin.nextLine().trim();
                        if (!val.isEmpty()) keys.put(varName, val);
                        else if (!old.isEmpty()) keys.put(varName, old);
                        saveAPIKeys(palladiumHome, keys);
                        System.out.println("  " + GREEN + label + " key saved." + NC);
                        pause();
                    }
                } catch (NumberFormatException ignored) {}
            } else if (ch.equals("r")) {
                List<String[]> setKeys = new ArrayList<>();
                for (String[] pair : API_KEY_NAMES) if (keys.containsKey(pair[0])) setKeys.add(pair);
                if (setKeys.isEmpty()) {
                    System.out.println("  " + YELLOW + "No keys to remove." + NC);
                    pause(); continue;
                }
                System.out.println("  " + BOLD + "Remove a key:" + NC);
                for (int j = 0; j < setKeys.size(); j++)
                    System.out.println("  [" + (j+1) + "] " + setKeys.get(j)[1]);
                System.out.print("  Which to remove: ");
                String idxStr = stdin.nextLine().trim();
                try {
                    int idx = Integer.parseInt(idxStr) - 1;
                    if (idx >= 0 && idx < setKeys.size()) {
                        keys.remove(setKeys.get(idx)[0]);
                        saveAPIKeys(palladiumHome, keys);
                        System.out.println("  " + GREEN + setKeys.get(idx)[1] + " key removed." + NC);
                        pause();
                    }
                } catch (NumberFormatException ignored) {}
            }
        }
    }

    // ── Entry ──

    public static void main(String[] args) {
        palladiumHome = findPalladium();
        if (palladiumHome == null) {
            System.out.println(RED + "Server must run from a Palladium installation." + NC);
            System.exit(1);
        }
        showMain();
    }
}
