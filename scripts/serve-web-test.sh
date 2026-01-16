#!/bin/bash
# =============================================================================
# serve-web-test.sh - Build and serve Flutter web wallet for E2E testing (CI mode)
# =============================================================================
#
# This script builds the marty-authenticator Flutter web app for production and
# serves it via a simple HTTP server. Designed for CI environments where:
#   1. Build output is cached and reproducible
#   2. Hot reload is not needed
#   3. Faster startup after initial build
#
# Usage:
#   ./scripts/serve-web-test.sh
#
# Environment Variables:
#   MARTY_API_URL - Backend API URL (default: http://localhost:8000)
#   WEB_PORT      - Port for HTTP server (default: 9081)
#   SKIP_BUILD    - Set to 'true' to skip build (use existing build/web)
#
# For local development with hot reload, use run-web-test.sh instead.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
MARTY_API_URL="${MARTY_API_URL:-http://localhost:8000}"
WEB_PORT="${WEB_PORT:-9081}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
SKIP_BUILD="${SKIP_BUILD:-false}"

cd "$PROJECT_DIR"

echo "🔧 Marty Authenticator - Web Test Build & Serve"
echo "================================================"
echo "API URL:    $MARTY_API_URL"
echo "Web Port:   $WEB_PORT"
echo "Skip Build: $SKIP_BUILD"
echo ""

# Wait for backend to be healthy
echo "⏳ Waiting for backend health check at $MARTY_API_URL/health..."

wait_count=0
until curl -sf "$MARTY_API_URL/health" > /dev/null 2>&1; do
  wait_count=$((wait_count + 1))
  if [ $wait_count -ge $HEALTH_TIMEOUT ]; then
    echo "❌ Backend health check timed out after ${HEALTH_TIMEOUT}s"
    echo "   Make sure the Marty backend is running at $MARTY_API_URL"
    exit 1
  fi
  echo "   Waiting... ($wait_count/${HEALTH_TIMEOUT}s)"
  sleep 1
done

echo "✅ Backend is healthy"
echo ""

# Build Flutter web if needed
if [ "$SKIP_BUILD" != "true" ]; then
  echo "🔨 Building Flutter web..."
  echo "   Entry point: lib/mains/main_web_test.dart"
  echo ""

  flutter build web \
    --target=lib/mains/main_web_test.dart \
    --dart-define=MARTY_API_URL="$MARTY_API_URL" \
    --dart-define=TEST_MODE=true \
    --release

  echo ""
  echo "✅ Build complete"
else
  echo "⏭️  Skipping build (SKIP_BUILD=true)"
fi

echo ""

# Serve the built web app
echo "🚀 Starting HTTP server on port $WEB_PORT..."
echo "   Serving: $PROJECT_DIR/build/web"
echo ""

cd "$PROJECT_DIR/build/web"

# Use Python's http.server with CORS support for better compatibility
exec python3 -c "
import http.server
import socketserver
import os

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

PORT = int(os.environ.get('WEB_PORT', $WEB_PORT))
with socketserver.TCPServer(('', PORT), CORSHTTPRequestHandler) as httpd:
    print(f'Serving at http://localhost:{PORT}')
    httpd.serve_forever()
"
