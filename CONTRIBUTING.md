# Contributing to Palladium

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USER/Palladium`
3. Run `./setup.sh` to prepare the environment

## Code Style

- All shell scripts use `#!/bin/bash` shebang
- Use `set -e` for scripts that should fail fast
- Color variables from `core.sh`: `${RED}`, `${GREEN}`, `${YELLOW}`, `${CYAN}`, `${NC}`
- Utility functions from `core.sh`: `prompt_value`, `prompt_password`, `confirm`, `press_enter`
- Safety helpers from `safety.sh`: `check_docker_available`, `check_storage`, `health_check`
- End interactive functions with `press_enter` so user can read output
- Use `clear 2>/dev/null || true` at the start of menu functions

## Adding a Marketplace Tool

Create a `.tool` file in `palladium/marketplace/`:
```
name: my-tool
desc: Brief description
category: ai|data|automation|web|devops
image: author/image:tag
port: 8080
vars: KEY=default,OTHER=default
```

## Testing

Run all tests before submitting:
```bash
bash tests/run.sh
```

## Pull Request Process

1. Update the `VERSION` file if applicable
2. Update `README.md` if adding features
3. Ensure all tests pass
4. Describe the change clearly in the PR description
