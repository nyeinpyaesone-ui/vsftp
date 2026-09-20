# Contributing to UniFi Network OS Docker Suite

Thank you for your interest in contributing! This document provides guidelines for contributing.

## 🎯 How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

* A clear, descriptive title
* Steps to reproduce the issue
* Expected vs actual behavior
* Environment details (OS, Docker version, hardware)
* Relevant logs and screenshots

**Example:**
```markdown
**Bug Summary**
Container fails to start on Raspberry Pi 4

**Steps to Reproduce**
1. Clone repository
2. Run setup.sh in unifi-uck-g2-opt
3. Observe error in docker logs

**Expected Behavior**
Container should start successfully

**Actual Behavior**
Exit code 137 (OOMKilled)

**Environment**
- Raspberry Pi 4 (4GB RAM)
- Ubuntu 22.04 LTS
- Docker 20.10.21
```

### Suggesting Enhancements

Enhancement suggestions should include:

* Use case and motivation
* Proposed solution
* Alternative approaches considered
* Impact on existing functionality

### Pull Requests

Before submitting a PR:

1. **Fork and branch off main**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow code standards**
   - Shell scripts: Use `shellcheck` for validation
   - YAML: Validate with `docker compose config`
   - Documentation: Update README.md if adding features

3. **Test your changes**
   - Verify all docker-compose files are valid
   - Test on at least one deployment profile
   - Ensure no hardcoded credentials

4. **Commit messages**
   ```
   feat: add memory limit configuration for Enterprise FS
   fix: resolve port conflict detection in setup script
   docs: update performance benchmarks in README
   ```

5. **Update documentation**
   - Add performance metrics if changing resource limits
   - Update trigger rate configurations if modifying automation
   - Reflect changes in repository status table

## 📋 Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/unifi-network-os-docker.git
cd unifi-network-os-docker

# Install development tools
sudo apt install shellcheck docker-compose-v2

# Validate changes
./validate.sh  # Create this script for local testing
```

## 🚀 Performance Testing Requirements

When submitting performance-related changes:

| Metric | Minimum Requirement | Test Method |
|--------|-------------------|-------------|
| Backup Write Speed | >40 MB/s | Sequential I/O test |
| Database Query Latency | <50ms p95 | MongoDB profiler |
| Container Startup | <90s | systemd journal |
| Memory Usage | Within documented limits | `docker stats` |

Include benchmark results in your PR description.

## 🔐 Security Guidelines

* Never commit passwords, API keys, or certificates
* Use environment variables for sensitive data
* Follow principle of least privilege for container permissions
* Validate all user inputs in scripts
* Keep base images updated

## 📝 Code Review Process

1. All PRs require at least one review
2. Automated CI checks must pass
3. Performance impact must be documented
4. Security implications must be addressed

## 🏷️ Versioning

We follow [Semantic Versioning](https://semver.org/):

* **MAJOR**: Breaking changes to deployment structure
* **MINOR**: New features, performance improvements
* **PATCH**: Bug fixes, security patches

## ❓ Questions?

Open an issue with the "question" label for any queries.

---

By contributing, you agree that your contributions will be licensed under the repository's license.
