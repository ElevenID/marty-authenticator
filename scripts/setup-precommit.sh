#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v pre-commit >/dev/null 2>&1; then
    echo "Install pre-commit first; see https://pre-commit.com/#install" >&2
    exit 1
fi
pre-commit validate-config
pre-commit install
printf '%s\n' 'Hooks installed. Run make check before committing.'
