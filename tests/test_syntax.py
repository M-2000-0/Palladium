"""Syntax and structure validation tests for Palladium."""
import os, re, sys, glob, subprocess
from pathlib import Path
from typing import List, Tuple

PROJECT = Path(r"C:\Users\HP\OneDrive\Desktop\Server project\palladium")

# Detect bash availability
_BASH = None
for candidate in [r"C:\Program Files\Git\bin\bash.exe",
                  r"C:\Program Files\Git\usr\bin\bash.exe",
                  r"C:\Windows\System32\bash.exe"]:
    if Path(candidate).exists():
        _BASH = candidate
        break
if not _BASH:
    # Check WSL
    try:
        subprocess.run(["wsl", "which", "bash"], capture_output=True, timeout=5)
        _BASH = "wsl bash -c"
    except: pass

FAIL, PASS = 0, 0

def test(name: str, ok: bool, detail: str = ""):
    global PASS, FAIL
    if ok:
        PASS += 1
    else:
        FAIL += 1
        print(f"  FAIL  {name}")
        if detail:
            for line in detail.strip().splitlines():
                print(f"        {line}")

def bash_syntax(filepath: Path) -> Tuple[bool, str]:
    if not _BASH:
        return False, "bash not found (install Git Bash or WSL)"
    try:
        if _BASH.startswith("wsl"):
            wsl_path = filepath.as_posix()
            if wsl_path[1:2] == ":":
                wsl_path = "/mnt/" + wsl_path[0].lower() + wsl_path[2:]
            cmd = f"{_BASH} 'bash -n \"{wsl_path}\" 2>&1'"
            r = subprocess.run(
                ["wsl", "bash", "-c", f"bash -n '{wsl_path}' 2>&1"],
                capture_output=True, text=True, timeout=15
            )
            ok = r.returncode == 0 and r.stdout.strip() == ""
            if ok: return True, ""
            return False, r.stdout.strip() or r.stderr.strip()
        else:
            r = subprocess.run(
                [_BASH, "-n", str(filepath)],
                capture_output=True, text=True, timeout=15
            )
            if r.returncode == 0: return True, ""
            return False, r.stderr or r.stdout
    except subprocess.TimeoutExpired:
        return False, "timed out"

def file_contains(filepath: Path, pattern: str) -> bool:
    try:
        content = filepath.read_text(encoding="utf-8", errors="replace")
        return re.search(pattern, content) is not None
    except: return False

def validate_yaml(filepath: Path) -> Tuple[bool, str]:
    try:
        import yaml
        with open(filepath, "r", encoding="utf-8") as f:
            yaml.safe_load(f)
        return True, ""
    except ImportError: return True, "(pyyaml not installed)"
    except yaml.YAMLError as e: return False, str(e)
    except Exception as e: return False, str(e)

def required_fields(filepath: Path, fields: List[str]) -> Tuple[bool, str]:
    try:
        content = filepath.read_text(encoding="utf-8", errors="replace")
        missing = [f for f in fields if f not in content]
        return (True, "") if not missing else (False, f"Missing: {', '.join(missing)}")
    except Exception as e: return False, str(e)

def safe_read(filepath: Path) -> str:
    try:
        return filepath.read_text(encoding="utf-8", errors="replace")
    except: return ""

def test_globals():
    print("\n--- Global Checks ---")
    env_path = PROJECT / ".env.example"
    test(".env.example exists", env_path.exists(), "")
    if env_path.exists():
        for fld in ["TZ=", "POSTGRES_USER=", "POSTGRES_PASSWORD=", "PUBLIC_PORT_BASE="]:
            test(f".env.example has {fld.replace('=', '')}", file_contains(env_path, fld), "")

    # Check service templates are valid YAML
    svc_dir = PROJECT / "palladium" / "services"
    if svc_dir.exists():
        for svc_file in sorted(svc_dir.glob("*.yml")):
            ok, det = validate_yaml(svc_file)
            test(f"Service template {svc_file.name} valid YAML", ok, det)

def test_marketplace():
    print("\n--- Marketplace .tool Files ---")
    mp_dir = PROJECT / "palladium" / "marketplace"
    test("marketplace dir exists", mp_dir.exists(), "")
    if not mp_dir.exists(): return
    tool_files = sorted(mp_dir.glob("*.tool"))
    test(f"Found {len(tool_files)} .tool files", len(tool_files) > 0, "")
    for tf in tool_files:
        content = safe_read(tf)
        name = tf.stem
        issues = []
        for field in ["name:", "desc:", "category:", "image:", "port:"]:
            if field not in content: issues.append(field.replace(":", ""))
        test(f"{name}.tool complete", not issues,
             f"Missing: {', '.join(issues)}" if issues else "")

def test_bash_syntax():
    print("\n--- Bash Syntax Check ---")
    if not _BASH:
        test("bash available", False, "Install Git Bash or WSL")
        return
    sh_files = list(PROJECT.glob("*.sh"))
    sh_files += list((PROJECT / "palladium").glob("*.sh"))
    sh_files += list((PROJECT / "palladium" / "modules").glob("*.sh"))
    sh_files.append(PROJECT / "palladium" / "palladium")
    for sh_file in sh_files:
        if not sh_file.exists(): continue
        ok, det = bash_syntax(sh_file)
        rel = sh_file.relative_to(PROJECT)
        test(f"{rel} syntax OK", ok, "See details above" if not ok else "")
        if ok:
            content = sh_file.read_bytes()
            has_cr = b"\r\n" in content
            test(f"{rel} unix line endings", not has_cr,
                 "Has CRLF endings" if has_cr else "")

def test_function_references():
    print("\n--- Function Reference Check ---")
    mod_dir = PROJECT / "palladium" / "modules"
    functions = {}
    for mf in sorted(mod_dir.glob("*.sh")):
        content = safe_read(mf)
        for m in re.finditer(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)', content, re.M):
            functions[m.group(1)] = mf.name

    declared = sorted(functions.keys())
    test(f"Total functions defined: {len(declared)}", len(declared) > 20,
         f"Found: {', '.join(declared[:10])}...")

    # Source check
    palladium_path = PROJECT / "palladium" / "palladium"
    if palladium_path.exists():
        sourced = set()
        for line in safe_read(palladium_path).splitlines():
            m = re.match(r'^source\s+"\$MODULES_DIR/(\w+\.sh)"', line)
            if m: sourced.add(m.group(1))
        module_files = set(f.name for f in mod_dir.glob("*.sh"))
        missing = module_files - sourced
        test("All modules sourced", not missing,
             f"Not sourced: {', '.join(sorted(missing))}" if missing else "")

    required = [
        "check_docker_available", "check_storage", "check_existing_service",
        "pull_image_with_fallback", "health_check", "run_with_retry",
        "show_install_error", "prompt_value", "prompt_password", "confirm",
        "press_enter", "wizard_install", "wizard_custom",
        "marketplace_browse", "svc_start", "svc_stop", "svc_remove",
    ]
    for ref in required:
        status = f"  in {functions[ref]}" if ref in functions else ""
        test(f"{ref}() defined", ref in functions, status)

def test_brace_balance():
    print("\n--- Brace Balance ---")
    for sh_file in sorted(PROJECT.glob("*.sh")):
        _check_brace(sh_file)
    for sh_file in sorted((PROJECT / "palladium" / "modules").glob("*.sh")):
        _check_brace(sh_file)
    _check_brace(PROJECT / "palladium" / "palladium")

def _check_brace(fp: Path):
    if not fp.exists(): return
    c = fp.read_text(encoding="utf-8", errors="replace")
    o, cl = c.count("{"), c.count("}")
    rel = fp.relative_to(PROJECT)
    test(f"{rel} braces ({o}:{cl})", o == cl,
         f"{'Open > Close' if o > cl else 'Close > Open'} by {abs(o-cl)}" if o != cl else "")

def test_ai_module():
    print("\n--- AI Module ---")
    ai_path = PROJECT / "palladium" / "modules" / "ai.sh"
    test("ai.sh exists", ai_path.exists(), "")
    if not ai_path.exists(): return

    ok, det = bash_syntax(ai_path)
    test("ai.sh syntax", ok, det)

    content = safe_read(ai_path)
    funcs = re.findall(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)', content, re.M)
    dupes = set(f for f in funcs if funcs.count(f) > 1)
    test("ai.sh no duplicate functions", not dupes,
         f"Duplicates: {', '.join(dupes)}" if dupes else "")
    test(f"ai.sh has {len(funcs)} functions", len(funcs) >= 10,
         f"Found {len(funcs)}")

def test_safety_module():
    print("\n--- Safety Module ---")
    saf_path = PROJECT / "palladium" / "modules" / "safety.sh"
    test("safety.sh exists", saf_path.exists(), "")
    if not saf_path.exists(): return

    ok, det = bash_syntax(saf_path)
    test("safety.sh syntax", ok, det)

    content = safe_read(saf_path)
    funcs = re.findall(r'^\w+\(\)\s*\{', content, re.M)
    test(f"safety.sh has {len(funcs)} functions", len(funcs) >= 9,
         f"Found {len(funcs)}")


if __name__ == "__main__":
    print(f"Palladium Test Suite")
    print(f"Project: {PROJECT}")
    print(f"Bash: {_BASH or 'NOT FOUND'}")
    print("=" * 50)

    test_globals()
    test_marketplace()
    test_bash_syntax()
    test_function_references()
    test_brace_balance()
    test_ai_module()
    test_safety_module()

    print("\n" + "=" * 50)
    print(f"Results: {PASS} passed, {FAIL} failed out of {PASS+FAIL} tests")
    sys.exit(1 if FAIL > 0 else 0)
