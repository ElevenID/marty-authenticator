#!/usr/bin/env bash
# Retained build/serve entry point; run-web-test.sh owns common launch behavior.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MARTY_WEB_TEST_MODE=serve exec bash "$SCRIPT_DIR/run-web-test.sh"
