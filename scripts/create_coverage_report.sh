#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
rm -f -- coverage/lcov.info
flutter test --coverage
test -s coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
