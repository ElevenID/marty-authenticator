#!/bin/bash

# Plugin Development Helper Script
# This script helps with common plugin development tasks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    echo "privacyIDEA Plugin Development Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start         Start all services (with build)"
    echo "  stop          Stop all services"
    echo "  restart       Restart privacyIDEA server (reload plugins)"
    echo "  logs          Show privacyIDEA server logs"
    echo "  dev           Open development environment"
    echo "  test-plugin   Test plugin installation"
    echo "  clean         Clean up containers and volumes"
    echo "  status        Show service status"
    echo ""
}

start_services() {
    echo "🚀 Starting all services..."
    cd docker && docker compose up -d --build && cd ..
    echo ""
    echo "🔄 Initializing privacyIDEA..."
    cd docker && ./init-privacyidea.sh && cd ..
    echo ""
    echo "✅ Services started!"
    echo "🌐 Authenticator Web App: http://localhost:3000"
    echo "🔐 privacyIDEA Admin: http://localhost:8080 (testadmin/admin123)"
    echo "💻 Development Environment: http://localhost:8443 (password: development)"
    echo ""
}

stop_services() {
    echo "🛑 Stopping all services..."
    cd docker && docker compose down && cd ..
    echo "✅ Services stopped!"
}

restart_privacyidea() {
    echo "🔄 Restarting privacyIDEA server to reload plugins..."
    cd docker && docker compose restart privacyidea && cd ..
    echo "✅ privacyIDEA restarted!"
    echo "📋 Check logs with: $0 logs"
}

show_logs() {
    echo "📋 Showing privacyIDEA server logs..."
    docker logs -f privacyidea-server
}

open_dev() {
    echo "💻 Opening development environment..."
    if command -v open >/dev/null 2>&1; then
        open http://localhost:8443
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open http://localhost:8443
    else
        echo "🌐 Please open http://localhost:8443 in your browser"
        echo "🔑 Password: developer"
    fi
}

test_plugin() {
    echo "🧪 Testing plugin installation..."

    # Check if demo token plugin exists
    if [[ -f "docker/plugins/custom-tokens/demotoken.py" ]]; then
        echo "✅ Demo token plugin found"
    else
        echo "❌ Demo token plugin not found"
        exit 1
    fi

    # Restart privacyIDEA to load plugins
    restart_privacyidea

    echo "⏳ Waiting for server to start..."
    sleep 10

    # Test if server is responding
    if curl -s http://localhost:8080/ > /dev/null; then
        echo "✅ Server is responding"
    else
        echo "❌ Server not responding"
        exit 1
    fi

    echo "🎉 Plugin testing complete!"
    echo "📋 Check the admin interface at http://localhost:8080 for new token types"
}

clean_all() {
    echo "🧹 Cleaning up containers and volumes..."
    cd docker && docker compose down -v && cd ..
    docker system prune -f
    echo "✅ Cleanup complete!"
}

show_status() {
    echo "📊 Service Status:"
    echo ""
    cd docker && docker compose ps && cd ..
    echo ""

    # Check if services are accessible
    echo "🔗 Service Health:"

    if curl -s http://localhost:8080/ > /dev/null; then
        echo "✅ privacyIDEA Server: http://localhost:8080"
    else
        echo "❌ privacyIDEA Server: Not accessible"
    fi

    if curl -s http://localhost:3000/ > /dev/null; then
        echo "✅ Authenticator Web App: http://localhost:3000"
    else
        echo "❌ Authenticator Web App: Not accessible"
    fi

    if curl -s http://localhost:8443/ > /dev/null; then
        echo "✅ Development Environment: http://localhost:8443"
    else
        echo "❌ Development Environment: Not accessible"
    fi
}

# Main command handling
case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_privacyidea
        ;;
    logs)
        show_logs
        ;;
    dev)
        open_dev
        ;;
    test-plugin)
        test_plugin
        ;;
    clean)
        clean_all
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
