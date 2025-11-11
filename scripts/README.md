# Scripts Directory

This directory contains various utility scripts for the project.

## Scripts Overview

### Build & Development Scripts

- **`create_arb_files.sh`** - Creates ARB (Application Resource Bundle) files for internationalization
- **`create_messages_from_arb.sh`** - Generates message files from ARB files for localization
- **`update_serialization.sh`** - Updates code generation for serialization (JSON, etc.)
- **`plugin-dev.sh`** - Development utilities for plugin management

### Testing Scripts

- **`create_coverage_report.sh`** - Runs Flutter tests and generates HTML coverage reports
- **`run_driver.sh`** - Runs Flutter integration/driver tests
- **`test_spruceid_integration.sh`** - Shell script for SpruceID integration testing
- **`test_spruceid_integration.dart`** - Dart script for SpruceID integration testing

### Setup Scripts

- **`setup-precommit.sh`** - Sets up comprehensive pre-commit hooks for the project

## Usage

Make sure scripts are executable before running:

```bash
chmod +x scripts/*.sh
```

Run scripts from the project root:

```bash
./scripts/script_name.sh
```

## Notes

- All scripts should be run from the project root directory
- Some scripts may require specific dependencies to be installed
- Check individual script content for specific requirements and usage instructions
