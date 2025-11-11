#!/bin/bash

# Pre-commit Configuration Manager
# This script helps switch between different pre-commit configurations

PRECOMMIT_DIR=".precommit"
CURRENT_LINK=".pre-commit-config.yaml"

echo "🔧 Pre-commit Configuration Manager"
echo "======================================"

# Check if .precommit directory exists
if [ ! -d "$PRECOMMIT_DIR" ]; then
    echo "❌ .precommit directory not found!"
    exit 1
fi

# List available configurations
echo ""
echo "📋 Available configurations:"
echo ""

configs=(
    "simple:Basic hooks only (fast)"
    "comprehensive:Full security and quality checks"
    "enhanced:Enhanced security with custom checks"
    "full:All available hooks (most thorough)"
    "config:Current working configuration"
)

for i in "${!configs[@]}"; do
    IFS=':' read -r name desc <<< "${configs[$i]}"
    echo "  $((i+1)). $name - $desc"
done

echo ""

# Show current configuration
if [ -L "$CURRENT_LINK" ]; then
    current=$(readlink "$CURRENT_LINK")
    current_name=$(basename "$current" .yaml | sed 's/.pre-commit-config-//')
    echo "📍 Current: $current_name"
else
    echo "📍 Current: No symlink found"
fi

echo ""
read -p "🔄 Switch to configuration (1-5) or 'q' to quit: " choice

case $choice in
    1)
        config_file="$PRECOMMIT_DIR/.pre-commit-config-simple.yaml"
        config_name="simple"
        ;;
    2)
        config_file="$PRECOMMIT_DIR/.pre-commit-config-comprehensive.yaml"
        config_name="comprehensive"
        ;;
    3)
        config_file="$PRECOMMIT_DIR/.pre-commit-config-enhanced.yaml"
        config_name="enhanced"
        ;;
    4)
        config_file="$PRECOMMIT_DIR/.pre-commit-config-full.yaml"
        config_name="full"
        ;;
    5)
        config_file="$PRECOMMIT_DIR/.pre-commit-config.yaml"
        config_name="working"
        ;;
    q|Q)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice!"
        exit 1
        ;;
esac

# Check if config file exists
if [ ! -f "$config_file" ]; then
    echo "❌ Configuration file not found: $config_file"
    exit 1
fi

# Update symlink
rm -f "$CURRENT_LINK"
ln -s "$config_file" "$CURRENT_LINK"

echo "✅ Switched to $config_name configuration"
echo "📁 Using: $config_file"

# Optional: Run a quick test
read -p "🧪 Test new configuration? (y/n): " test_choice
if [[ $test_choice =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔍 Testing configuration..."
    if pre-commit run --all-files --show-diff-on-failure; then
        echo "✅ All hooks passed!"
    else
        echo "⚠️  Some hooks failed - check output above"
    fi
fi

echo ""
echo "🎉 Configuration switch complete!"
