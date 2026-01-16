#!/bin/bash
# =============================================================================
# run-web-test.sh - Start Flutter web wallet for E2E testing (development mode)
# =============================================================================
#
# This script starts the marty-authenticator Flutter web app in development mode
# for local E2E testing with Playwright. It:
#   1. Waits for the backend API to be healthy
#   2. Starts Flutter web with hot reload enabled
#   3. Configures the app for test mode with SSE push notifications
#
# Usage:
#   ./scripts/run-web-test.sh
#
# Environment Variables:
#   MARTY_API_URL - Backend API URL (default: http://localhost:8000)
#   WEB_PORT      - Port for Flutter web server (default: 9081)
#
# For CI/production builds, use serve-web-test.sh instead.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
MARTY_API_URL="${MARTY_API_URL:-http://localhost:8000}"
WEB_PORT="${WEB_PORT:-9081}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"

cd "$PROJECT_DIR"

echo "🔧 Marty Authenticator - Web Test Mode"
echo "======================================="
echo "API URL:  $MARTY_API_URL"
echo "Web Port: $WEB_PORT"
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

# Start Flutter web in development mode
echo "🚀 Starting Flutter web on port $WEB_PORT..."
echo "   Entry point: lib/mains/main_web_test.dart"
echo ""

exec flutter run \
  -d chrome \
  --web-port="$WEB_PORT" \
  --target=lib/mains/main_web_test.dart \
  --dart-define=MARTY_API_URL="$MARTY_API_URL" \
  --dart-define=TEST_MODE=true
