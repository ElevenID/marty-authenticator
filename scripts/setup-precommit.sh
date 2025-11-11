#!/bin/bash

# Enhanced pre-commit setup script for Flutter/Dart + Python project
# This script installs pre-commit and sets up comprehensive hooks

set -e

echo "🚀 Setting up enhanced pre-commit environment..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if pre-commit is installed
if ! command_exists pre-commit; then
    echo "📦 Installing pre-commit..."

    # Try to install via pip
    if command_exists pip3; then
        pip3 install pre-commit
    elif command_exists pip; then
        pip install pre-commit
    elif command_exists brew; then
        # macOS with Homebrew
        brew install pre-commit
    else
        echo "❌ Could not install pre-commit. Please install it manually:"
        echo "   pip install pre-commit"
        echo "   or visit: https://pre-commit.com/#installation"
        exit 1
    fi
fi

# Install comprehensive Python security and quality tools
echo "📦 Installing Python tools for code quality and security..."
tools=(
    "ruff"           # Fast linter and formatter
    "isort"          # Import sorting
    "bandit"         # Security scanner
    "detect-secrets" # Secret detection
    "safety"         # Dependency vulnerability scanner
    "pip-audit"      # Alternative dependency scanner
    "mypy"           # Type checking
    "vulture"        # Dead code detection
    "pydocstyle"     # Docstring linting
    "radon"          # Code complexity
    "xenon"          # Code complexity with thresholds
    "semgrep"        # SAST security scanning
)

pip_cmd="pip3"
if ! command_exists pip3; then
    if command_exists pip; then
        pip_cmd="pip"
    else
        echo "❌ No pip found. Please install Python and pip first."
        exit 1
    fi
fi

for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
        echo "  Installing $tool..."
        $pip_cmd install "$tool" || echo "⚠️  Warning: Failed to install $tool"
    else
        echo "  ✅ $tool already installed"
    fi
done

# Install additional tools via system package manager if available
if command_exists brew; then
    echo "📦 Installing additional tools via Homebrew..."
    brew_tools=("gitleaks" "markdownlint-cli")
    for tool in "${brew_tools[@]}"; do
        if ! command_exists "${tool%%-*}"; then  # Remove suffix for command check
            echo "  Installing $tool..."
            brew install "$tool" || echo "⚠️  Warning: Failed to install $tool via brew"
        else
            echo "  ✅ $tool already installed"
        fi
    done
fi

# Install Node.js tools for markdown processing (if npm is available)
if command_exists npm; then
    echo "📦 Installing Node.js tools..."
    npm_tools=("prettier" "@prettier/plugin-xml")
    for tool in "${npm_tools[@]}"; do
        if ! npm list -g "$tool" >/dev/null 2>&1; then
            echo "  Installing $tool..."
            npm install -g "$tool" || echo "⚠️  Warning: Failed to install $tool via npm"
        else
            echo "  ✅ $tool already installed globally"
        fi
    done
fi

# Check if Flutter is installed
if ! command_exists flutter; then
    echo "❌ Flutter not found. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if Dart is available
if ! command_exists dart; then
    echo "❌ Dart not found. Please ensure Flutter installation includes Dart SDK."
    exit 1
fi

# Install Flutter/Dart development dependencies
echo "📦 Installing Flutter dev dependencies..."
flutter pub get
if ! flutter pub run dependency_validator --help >/dev/null 2>&1; then
    echo "  Installing dependency_validator..."
    flutter pub add --dev dependency_validator || echo "⚠️  Failed to install dependency_validator"
fi
if ! flutter pub run dart_code_metrics --help >/dev/null 2>&1; then
    echo "  Installing dart_code_metrics..."
    flutter pub add --dev dart_code_metrics || echo "⚠️  Failed to install dart_code_metrics"
fi

echo "✅ All required tools are available!"

# Install the pre-commit hooks
echo "🔧 Installing pre-commit hooks..."
pre-commit install

# Create initial secrets baseline if it doesn't exist
if [ ! -f .secrets.baseline ]; then
    echo "🔧 Creating initial secrets baseline..."
    detect-secrets scan --baseline .secrets.baseline || echo "⚠️  Could not create secrets baseline"
fi

# Run pre-commit on all files to test the setup
echo "🧪 Testing pre-commit hooks on all files..."
echo "   (This may take a while on the first run as it downloads hook environments)"

if pre-commit run --all-files; then
    echo "✅ All pre-commit hooks passed!"
else
    echo "⚠️  Some hooks failed or made changes. This is normal on first setup."
    echo "   The hooks have automatically fixed issues where possible."
    echo "   Please review the changes and commit them."
fi

echo ""
echo "🎉 Enhanced pre-commit setup complete!"
echo ""
echo "Your comprehensive pre-commit hooks are now active:"
echo ""
echo "🔍 Code Quality (9 checks):"
echo "  ✓ Dart formatting (dart format)"
echo "  ✓ Flutter analysis (flutter analyze)"
echo "  ✓ Dart fixes check (dart fix)"
echo "  ✓ Python formatting (ruff format - replaces Black)"
echo "  ✓ Python linting (ruff check - replaces flake8/pylint)"
echo "  ✓ Python import sorting (isort)"
echo "  ✓ Python type checking (mypy)"
echo "  ✓ Python docstring linting (pydocstyle)"
echo "  ✓ Code complexity checks (xenon, dart_code_metrics)"
echo ""
echo "🔒 Security (8 checks):"
echo "  ✓ Secret detection (detect-secrets)"
echo "  ✓ Deep secret scanning (gitleaks)"
echo "  ✓ Security pattern analysis (semgrep)"
echo "  ✓ Python vulnerability scan (bandit)"
echo "  ✓ Dependency vulnerability scan (safety, pip-audit)"
echo "  ✓ Private key detection"
echo "  ✓ Custom security checks (API keys, passwords, etc.)"
echo "  ✓ Flutter security configuration checks"
echo ""
echo "📋 File Quality (12 checks):"
echo "  ✓ General file checks (trailing whitespace, etc.)"
echo "  ✓ YAML/JSON/Markdown formatting (prettier)"
echo "  ✓ Markdown linting (markdownlint)"
echo "  ✓ Link validation (markdown-link-check)"
echo "  ✓ Import order validation"
echo "  ✓ Asset existence validation"
echo "  ✓ Dependency validation"
echo "  ✓ Dead code detection (vulture)"
echo ""
echo "🛠️  Development Commands:"
echo "  make help            # Show all available commands"
echo "  make check           # Run all quality checks"
echo "  make security        # Run security scans"
echo "  make complexity      # Check code complexity"
echo "  make type-check      # Run type checking"
echo "  make docs            # Check documentation"
echo "  make pre-commit      # Run hooks manually"
echo "  make clean           # Clean caches and artifacts"
echo ""
echo "⚡ Quick Commands:"
echo "  pre-commit run --all-files    # Run all hooks"
echo "  pre-commit run <hook-id>      # Run specific hook"
echo "  pre-commit autoupdate         # Update hook versions"
echo "  git commit --no-verify        # Skip hooks (not recommended)"
echo ""
echo "🚨 Emergency Commands:"
echo "  make quality-gate    # Strict quality checks"
echo "  SKIP=hook-name git commit -m \"message\"  # Skip specific hook"
echo ""
echo "📚 For more information, see PRE_COMMIT_SETUP.md"
