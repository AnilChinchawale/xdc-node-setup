# Contributing to XDC Node Setup

Thank you for your interest in contributing to XDC Node Setup! This document provides guidelines and standards for contributing to this enterprise-grade XDC Network node deployment toolkit.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Code Style Guidelines](#code-style-guidelines)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Security](#security)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- Be respectful and inclusive
- Focus on constructive feedback
- Accept constructive criticism gracefully
- Prioritize the community's best interests

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a new branch for your feature or fix
4. Make your changes following our guidelines
5. Submit a pull request

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/XDC-Node-Setup.git
cd XDC-Node-Setup

# Create a branch
git checkout -b feature/your-feature-name

# Make changes and commit
git add .
git commit -m "feat: add your feature"
git push origin feature/your-feature-name
```

## Development Environment

### Prerequisites

- Ubuntu 20.04/22.04/24.04 (for testing)
- Bash 5.0+
- Docker and Docker Compose
- Ansible 2.12+
- Terraform 1.3+ (for infrastructure work)
- kubectl and Helm (for Kubernetes work)

### Setup Development Environment

```bash
# Install development dependencies
./scripts/setup-dev.sh

# Run pre-commit hooks
pre-commit install

# Run tests
./scripts/test.sh
```

## Code Style Guidelines

### Shell Scripts

All shell scripts must follow these standards:

1. **Shebang**: Use `#!/usr/bin/env bash`
2. **Strict Mode**: Always include `set -euo pipefail`
3. **ShellCheck**: All scripts must pass ShellCheck linting
4. **Documentation**: Include header comments with purpose and usage

```bash
#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Script Name - Brief description
#==============================================================================

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/script.log"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

main() {
    # Main logic here
}

main "$@"
```

### Ansible

Follow Ansible best practices:

```yaml
---
# Task file with descriptive name
- name: Descriptive task name
  ansible.builtin.package:
    name: "{{ package_name }}"
    state: present
  tags: [tag1, tag2]
  notify: Handler name
```

- Use FQCN (Fully Qualified Collection Names) for modules
- Name all tasks descriptively
- Use proper YAML formatting (2-space indentation)
- Tag all tasks appropriately
- Use handlers for service restarts

### Terraform

Follow HashiCorp style guidelines:

```hcl
resource "aws_instance" "xdc_node" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = "xdc-node"
    Environment = var.environment
  }
}
```

- Use `snake_case` for resources and variables
- Always format with `terraform fmt`
- Document all variables in `variables.tf`
- Use meaningful resource names

## Commit Message Format

We follow the Conventional Commits specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes
- `security`: Security-related changes

### Scopes

- `ansible`: Ansible playbooks and roles
- `scripts`: Shell scripts
- `terraform`: Terraform configurations
- `k8s`: Kubernetes manifests and Helm charts
- `docker`: Docker configurations
- `docs`: Documentation
- `ci`: CI/CD workflows

### Examples

```
feat(ansible): add rolling update playbook

Implement serial: 1 deployment with health checks
after each node update to ensure zero-downtime.

Refs: #123
```

```
fix(scripts): correct block height comparison in health check

The health check was using incorrect hex to decimal conversion
for block height comparison.

Closes: #456
```

## Pull Request Process

1. **Update Documentation**: Update README.md or relevant docs
2. **Add Tests**: Include tests for new functionality
3. **Update CHANGELOG**: Add entry to CHANGELOG.md
4. **Request Review**: Request review from maintainers
5. **Address Feedback**: Make requested changes
6. **Merge**: Maintainers will merge after approval

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added and passing
- [ ] CHANGELOG.md updated
- [ ] No breaking changes (or clearly documented)

## Testing Requirements

### Shell Script Testing

```bash
# Run ShellCheck
find . -name "*.sh" -type f | xargs shellcheck -e SC1091

# Run bats tests
./tests/run-bats-tests.sh
```

### Ansible Testing

```bash
# Syntax check
ansible-playbook --syntax-check playbooks/*.yml

# Dry run
ansible-playbook --check playbooks/deploy-node.yml

# Molecule tests
cd ansible/roles/xdc-node
molecule test
```

### Terraform Testing

```bash
# Validate
cd terraform/aws
terraform validate

# Format check
terraform fmt -check

# Plan
terraform plan
```

## Documentation

### Code Documentation

- All functions must have docstrings
- Complex algorithms need inline comments
- Configuration options must be documented

### User Documentation

- Update relevant docs/ files
- Include examples
- Keep README.md in sync
- Update architecture diagrams if needed

## Security

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities.

Instead:
1. Email security concerns to: security@xdc.dev
2. Include detailed description and reproduction steps
3. Allow time for assessment before public disclosure

### Security Best Practices

- Never commit secrets or credentials
- Use environment variables for sensitive data
- Follow least privilege principle
- Validate all inputs
- Use secure defaults

## Release Process

1. **Version Bump**: Update version in relevant files
2. **CHANGELOG**: Ensure all changes are documented
3. **Tag**: Create signed git tag
4. **Build**: Run release build
5. **Test**: Verify release artifacts
6. **Publish**: Create GitHub release

```bash
# Example release process
git checkout main
git pull origin main
./scripts/bump-version.sh 2.1.0
git commit -am "chore: bump version to 2.1.0"
git tag -s v2.1.0 -m "Release version 2.1.0"
git push origin main --tags
```

## Questions?

- Join our [Discord](https://discord.gg/xdc)
- Open a [Discussion](https://github.com/AnilChinchawale/XDC-Node-Setup/discussions)
- Email: anil24593@gmail.com

Thank you for contributing! 🚀
