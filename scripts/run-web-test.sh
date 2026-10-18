#!/usr/bin/env bash
# Shared launcher for the development and build/serve web test entry points.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
MARTY_API_URL="${MARTY_API_URL:-http://localhost:8000}"
WEB_PORT="${WEB_PORT:-9081}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
SKIP_BUILD="${SKIP_BUILD:-false}"
mode="${MARTY_WEB_TEST_MODE:-dev}"
case "$mode" in
  dev|serve) ;;
  *) echo "Unknown web test mode: $mode" >&2; exit 1 ;;
esac
cd -- "$PROJECT_DIR"

# A cached build cannot qualify a missing test application.
if [[ ! -f lib/mains/main_web_test.dart ]]; then
  echo "Web wallet test entrypoint is missing: lib/mains/main_web_test.dart" >&2
  echo "See docs/development-checks.md for unfinished web harness requirements." >&2
  exit 1
fi

printf 'Marty web wallet test: mode=%s API=%s port=%s\n' "$mode" "$MARTY_API_URL" "$WEB_PORT"
wait_count=0
until curl -sf "$MARTY_API_URL/health" > /dev/null 2>&1; do
  wait_count=$((wait_count + 1))
  if [[ $wait_count -ge $HEALTH_TIMEOUT ]]; then
    echo "Backend health check timed out after ${HEALTH_TIMEOUT}s" >&2
    exit 1
  fi
  sleep 1
done

flutter_args=(
  --target=lib/mains/main_web_test.dart
  "--dart-define=MARTY_API_URL=$MARTY_API_URL"
  --dart-define=TEST_MODE=true
)
if [[ "$mode" == dev ]]; then
  exec flutter run -d chrome "--web-port=$WEB_PORT" "${flutter_args[@]}"
fi

if [[ "$SKIP_BUILD" != true ]]; then
  flutter build web "${flutter_args[@]}" --release
fi
if [[ ! -f build/web/index.html ]]; then
  echo "Web test output is missing: build/web/index.html" >&2
  exit 1
fi
cd -- "$PROJECT_DIR/build/web"
export WEB_PORT
# Pass configuration as data, never interpolate it into Python source.
exec python3 -c '
import http.server
import os
import socketserver

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

port = int(os.environ["WEB_PORT"])
with socketserver.TCPServer(("", port), CORSHTTPRequestHandler) as httpd:
    print(f"Serving at http://localhost:{port}")
    httpd.serve_forever()
'
