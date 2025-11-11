# Pre-commit Configuration Files

This folder contains all the pre-commit related configuration files and supporting documents.

## Files

### Configuration Files

- **`.pre-commit-config.yaml`** - Main pre-commit configuration with 33+ hooks
- **`.pre-commit-config-simple.yaml`** - Simplified version with basic hooks only
- **`.pre-commit-config-comprehensive.yaml`** - Comprehensive version with all security tools
- **`.pre-commit-config-full.yaml`** - Full version with all available hooks
- **`.pre-commit-config-enhanced.yaml`** - Enhanced version with additional security checks

### Supporting Files

- **`.secrets.baseline`** - Baseline file for detect-secrets to manage false positives
- **`.vulture_whitelist`** - Whitelist file for vulture dead code detection (currently unused)
- **`.markdownlint.yml`** - Configuration for markdown linting (currently disabled)

## Setup

The main configuration file (`.pre-commit-config.yaml`) is symlinked from the repository root to maintain compatibility with pre-commit's expected file location.

## Current Status

✅ **33 hooks passing** out of 36 total (3 skipped, 0 failed)

### Active Security Tools

- detect-secrets - Comprehensive secret detection
- gitleaks - Git history secret scanning
- bandit - Python security linting
- Custom API key detection
- Custom password detection
- Custom HTTP security check
- Flutter security configuration
- Copyright header validation

### Quality Tools

- ruff - Python linting and formatting
- isort - Import sorting
- mypy - Type checking
- xenon - Code complexity analysis
- Various file format validators
- Dart formatting and analysis

## Usage

```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run <hook-name> --all-files

# Install hooks for automatic execution
pre-commit install

# Switch between different configurations
./.precommit/switch-config.sh
```

## Development Notes

Some hooks are disabled for development workflow:

- vulture (dead code detection) - Too many false positives in development code
- pydocstyle (docstring linting) - Many files need documentation work
- markdownlint - Documentation formatting issues
- TODO/FIXME detection - Active development with legitimate TODOs
- Branch protection - Allows commits to main during development
