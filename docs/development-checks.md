# Development checks

Install Flutter, Node/npm and pre-commit, then run `make dev-setup`. The setup
restores declared dependencies, validates the single root
`.pre-commit-config.yaml`, and installs hooks. It does not add Dart dependencies
or install a separate Python lint/security toolchain globally.

Use `make check` for Flutter analysis and repository hooks, `make test` for
Flutter tests, and `make security` for the pinned Gitleaks hook. Failures propagate
to the caller. Gitleaks extends its maintained default rules without a generated
baseline. File-format, Markdown links, Dart and local security hooks remain in
the root configuration. Existing live-QR and platform build targets remain.

The Python extension prototype is retired, with its unfinished feature intent in
[Python issuer integration](python-issuer-integration.md). There are no tracked
Python source files to lint; the web test server still uses a small Python
standard-library command. Pre-commit itself may also require Python, but that is
not a Python application dependency.
