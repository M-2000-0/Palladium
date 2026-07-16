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

## Security Practices

- All default passwords must be changed before exposing services to a network
- The secrets vault uses AES-256 encryption (OpenSSL)
- Environment files (`.env`) are excluded from version control
- Docker containers run with least-privilege by default
