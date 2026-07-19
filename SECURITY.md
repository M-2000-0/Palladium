# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Palladium, please report it privately.

**Do not** open a public GitHub issue. Instead, email the project maintainer or open a draft security advisory at:
https://github.com/M-2000-0/Palladium/security/advisories/new

You should receive a response within 48 hours. If you don't, please follow up.

## What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact
- Any suggested fix (optional)

## Scope

- The Palladium CLI (`palladium/palladium` and modules)
- Marketplace tools and service templates
- Installer scripts
- Build and deployment process

Out of scope: third-party services installed via Palladium (Docker images, APIs, etc.).

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes    |
| < 1.0   | ❌ No     |

## Security Features

### Secrets Vault
- AES-256 encryption via OpenSSL (PBKDF2, 100,000 iterations)
- Master password never stored, only derived key
- Per-secret encryption available
- Secure temporary file handling with `shred`

### Two-Factor Authentication (TOTP)
- RFC 6238 compliant TOTP
- Compatible with Google Authenticator, Authy, 1Password, etc.
- QR code generation for easy setup
- Protects CLI access when enabled

### Audit Logging
- All security events logged to `data/audit.log`
- Events: login, 2FA verify, secret access, rotation, config changes
- Levels: SUCCESS, FAILURE, INFO
- Tamper-evident append-only format

### Secrets Rotation
- Age tracking for all vault secrets
- Bulk rotation for secrets older than N days
- Expiration date support
- Automatic audit log entries

### CIS Docker Benchmark
- Automated security audit against CIS Docker Benchmark v1.6.0
- Checks: daemon config, container runtime, images, host config
- Categories: PASS, WARN, FAIL
- Runs in < 30 seconds

### Input Validation
- SQL injection prevention in Data workspace
- Port validation (1-65535)
- Instance name validation (alphanumeric, hyphen, underscore)
- Password strength requirements (8+ chars, letter + number)

### Network Security
- Shared `palladium` Docker network for service isolation
- No host network mode by default
- Read-only root filesystem option
- Non-root user enforcement
- Capability dropping

### File Permissions
- Vault: 600 (owner read/write only)
- Config files: 600
- Scripts: 755
- Temporary files: secure `mktemp` with cleanup

## Security Practices

- All default passwords must be changed before exposing services to a network
- Environment files (`.env`) are excluded from version control
- Docker containers run with least-privilege by default
- Regular dependency updates via GitHub Dependabot
- ShellCheck static analysis in CI
- No `eval` or unquoted variable expansion
- No hardcoded secrets in codebase

## Hardening Checklist for Production

- [ ] Enable 2FA for CLI access
- [ ] Change all default passwords (use `palladium security` → Password Audit)
- [ ] Configure firewall (`palladium security` → Firewall)
- [ ] Set up HTTPS/TLS (`palladium security` → HTTPS Setup)
- [ ] Enable audit log monitoring
- [ ] Schedule secrets rotation (90 days)
- [ ] Run CIS Docker Bench monthly
- [ ] Configure Alertmanager for security alerts
- [ ] Backup vault and audit log separately
- [ ] Review installed services for unnecessary exposure

## Known Security Considerations

1. **Docker Socket Access**: Palladium requires Docker CLI access. On Linux, this typically means the user is in the `docker` group (equivalent to root). Consider rootless Docker for multi-user systems.

2. **API Key Storage**: The REST API key is stored in plaintext at `data/api/key`. Protect this file (chmod 600) and rotate periodically.

3. **Secrets Vault**: The master password is the single point of failure. Use a strong, unique password. Consider a password manager.

4. **Marketplace Tools**: Community-submitted tools are not audited. Review `.tool` files before installing. Use `palladium marketplace` → Custom Install for untrusted images.

5. **Backup Encryption**: Backups created via `palladium backup` are not encrypted by default. Use `--encrypt` flag or restic/rclone for encrypted cloud backups.

## Security Updates

Security patches are released as patch versions (e.g., 1.1.1) and announced via:
- GitHub Security Advisories
- Release notes
- In-app update notification (`palladium updates`)

## Contact

For security concerns not suitable for public disclosure, contact the maintainers directly via the GitHub security advisory process.