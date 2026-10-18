# Scripts Directory

This directory contains various utility scripts for the project.

## Scripts Overview

### Build & Development Scripts

- **`update_serialization.sh`** - Updates code generation for serialization (JSON, etc.)
- **`plugin-dev.sh`** - Development utilities for plugin management

### Testing Scripts

- **`create_coverage_report.sh`** - Runs Flutter tests from the checkout root and generates HTML coverage only after they pass; failures from either tool return nonzero
- **`run_driver.sh`** - Runs Flutter integration/driver tests

### Setup Scripts

- **`setup-precommit.sh`** - Validates and installs the single root pre-commit configuration

## Localization

Localization sources are the reviewed `lib/l10n/app_*.arb` files. Update the
English template and locale translations, then run from the repository root:

```bash
flutter pub get
flutter gen-l10n
```

[`l10n.yaml`](../l10n.yaml) selects the template and generated output; build,
test, and release workflows use this same Flutter generator. Application code
uses generated `AppLocalizations`. The removed `intl_translation` wrappers
referenced an undeclared package and missing `localization_utils.dart`; they
were not the current extraction or generation owner. No ARB source, locale,
localization configuration, or generated application import is removed.

Coverage output under `coverage/` is ignored local evidence. The tracked LCOV
snapshot is retired; the wrapper removes old LCOV output, requires tests to pass
and a fresh nonempty report, then renders HTML. Failed tests cannot reuse the
snapshot as new acceptance. Install Flutter and the LCOV `genhtml` tool before using
the coverage wrapper. The retired SpruceID mock scripts are not qualification
commands; their unfinished integration intent remains in the guide linked below.

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

See [development checks](../docs/development-checks.md) and
[unfinished Python issuer integration](../docs/python-issuer-integration.md).
