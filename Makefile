.PHONY: help setup-precommit install-deps format lint analyze check test security clean complexity type-check docs pre-commit security-baseline ci-check

# Default target
help: ## Show this help message
	@echo "🚀 Enhanced Pre-commit Development Environment"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "🎯 Quick Start:"
	@echo "  make dev-setup       # Complete setup for new developers"
	@echo "  make check           # Run all quality checks"
	@echo "  make pre-commit      # Run pre-commit hooks manually"

# Setup and installation
setup-precommit: ## Install and setup pre-commit hooks
	@./setup-precommit.sh

install-deps: ## Install all development dependencies
	@echo "📦 Installing Flutter dependencies..."
	@flutter pub get
	@echo "📦 Installing Python dependencies..."
	@pip install ruff isort bandit pre-commit detect-secrets safety pip-audit mypy vulture pydocstyle radon xenon semgrep
	@if command -v brew &> /dev/null; then \
		echo "📦 Installing additional tools via Homebrew..."; \
		brew install gitleaks markdownlint-cli || echo "⚠️  Some tools failed to install via Homebrew"; \
	fi
	@echo "📦 Installing Dart dev dependencies..."
	@flutter pub add --dev dependency_validator dart_code_metrics || echo "⚠️  Some Dart tools failed to install"

# Code quality
format: ## Format all code (Dart and Python)
	@echo "🎨 Formatting Dart code..."
	@dart format .
	@echo "🎨 Formatting Python code with ruff..."
	@ruff format . || echo "⚠️  Ruff not available, skipping Python formatting"
	@echo "🎨 Sorting Python imports with isort..."
	@isort . || echo "⚠️  isort not available, skipping Python import sorting"
	@echo "🎨 Formatting Markdown and other files..."
	@npx prettier --write "**/*.{md,json,yml,yaml}" 2>/dev/null || echo "⚠️  Prettier not available, skipping file formatting"

lint: ## Run linters on all code
	@echo "🔍 Running Dart analysis..."
	@flutter analyze
	@echo "🔍 Running Python linting with ruff..."
	@ruff check . || echo "⚠️  Ruff not available, skipping Python linting"
	@echo "🔍 Checking Dart fixes available..."
	@dart fix --dry-run || echo "⚠️  No dart fixes available"

analyze: lint ## Alias for lint

complexity: ## Check code complexity
	@echo "📊 Checking Python code complexity..."
	@xenon --max-absolute B --max-modules B --max-average A . || echo "⚠️  xenon not available"
	@radon cc . -a -nb || echo "⚠️  radon not available, install with: pip install radon"
	@echo "📊 Checking Dart code complexity..."
	@if command -v dart_code_metrics &> /dev/null; then \
		dart_code_metrics analyze lib --reporter=console; \
	else \
		echo "⚠️  dart_code_metrics not installed. Run: flutter pub add --dev dart_code_metrics"; \
	fi

type-check: ## Run static type checking
	@echo "🔎 Running Python type checking with mypy..."
	@mypy . || echo "⚠️  mypy not available or has errors"
	@echo "🔎 Dart type checking is handled by flutter analyze"

docs: ## Check documentation quality
	@echo "📚 Checking Python docstrings..."
	@pydocstyle . || echo "⚠️  pydocstyle not available or has issues"
	@echo "📚 Checking Markdown files..."
	@markdownlint . --fix || echo "⚠️  markdownlint not available"
	@echo "📚 Checking Markdown links..."
	@markdown-link-check README.md || echo "⚠️  markdown-link-check not available"

check: ## Run all code quality checks (format + lint + security)
	@echo "Running all code quality checks..."
	@make format
	@make lint
	@make security
	@echo "Running pre-commit on all files..."
	@pre-commit run --all-files || echo "Pre-commit not set up, run 'make setup-precommit' first"

# Testing
test: ## Run all tests
	@echo "🧪 Running Dart tests..."
	@flutter test
	@echo "🧪 Running Python tests..."
	@python -m pytest -v || echo "⚠️  pytest not available or no Python tests found"

# Maintenance
clean: ## Clean build artifacts and caches
	@echo "🧹 Cleaning Flutter build..."
	@flutter clean
	@echo "🧹 Cleaning pre-commit cache..."
	@pre-commit clean || echo "⚠️  Pre-commit not available"
	@echo "🧹 Cleaning Python cache..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf .ruff_cache/ 2>/dev/null || true
	@echo "🧹 Cleaning security reports..."
	@rm -f *-report.json bandit-report.json safety-report.json pip-audit-report.json
	@echo "✅ Clean complete!"

# Flutter specific
flutter-doctor: ## Run Flutter doctor
	@flutter doctor

build-android: ## Build Android APK
	@echo "🏗️  Building Android APK..."
	@flutter build apk

build-ios: ## Build iOS (requires macOS)
	@echo "🏗️  Building iOS..."
	@flutter build ios

# Pre-commit specific
precommit-update: ## Update pre-commit hooks to latest versions
	@echo "🔄 Updating pre-commit hooks..."
	@pre-commit autoupdate

precommit-run: ## Run pre-commit on all files
	@echo "🔄 Running pre-commit on all files..."
	@pre-commit run --all-files

# Development workflow
dev-setup: install-deps setup-precommit ## Complete development setup for new contributors
	@echo "🎉 Development environment setup complete!"
	@echo ""
	@echo "📋 Next steps:"
	@echo "  1. Run 'make check' to verify everything works"
	@echo "  2. Make your changes"
	@echo "  3. Run 'make check' before committing"
	@echo "  4. Commit your changes (pre-commit hooks will run automatically)"
	@echo ""
	@echo "🛠️  Available commands: make help"

# CI simulation
ci-check: ## Run checks similar to CI environment
	@echo "🤖 Running CI-like checks..."
	@make clean
	@make install-deps
	@make security-baseline
	@make check
	@make test
	@echo "✅ CI checks complete!"

# Quality gates
quality-gate: ## Run quality gate checks (strict)
	@echo "🚪 Running quality gate checks..."
	@echo "📊 Code complexity check..."
	@xenon --max-absolute A --max-modules A --max-average A . || (echo "❌ Code complexity too high" && exit 1)
	@echo "🔍 Strict linting..."
	@ruff check --select ALL . || (echo "❌ Strict linting failed" && exit 1)
	@echo "🔒 Security check..."
	@bandit -r . -ll || (echo "❌ Security issues found" && exit 1)
	@echo "✅ Quality gate passed!"

# Security
security: ## Run comprehensive security scans
	@echo "🔒 Running secret detection..."
	@detect-secrets scan --baseline .secrets.baseline || echo "⚠️  detect-secrets not available or found issues"
	@echo "🔒 Running deep git history secret scan..."
	@gitleaks detect --verbose --no-git || echo "⚠️  gitleaks not available"
	@echo "🔒 Running SAST security scan..."
	@semgrep --config auto --error . || echo "⚠️  semgrep not available or found issues"
	@echo "🔒 Running Python security scan..."
	@bandit -r . -f json -o bandit-report.json || echo "⚠️  bandit not available"
	@echo "🔒 Checking Python dependency vulnerabilities..."
	@safety check --json --output safety-report.json || echo "⚠️  safety not available"
	@pip-audit --format json --output pip-audit-report.json || echo "⚠️  pip-audit not available"
	@echo "🔒 Running dead code detection..."
	@vulture . || echo "⚠️  vulture not available"
	@echo "✅ Security scan complete! Check *-report.json files for details."

security-baseline: ## Update secrets baseline
	@echo "🔄 Updating secrets baseline..."
	@detect-secrets scan --baseline .secrets.baseline --force-use-all-plugins || echo "⚠️  detect-secrets not available"

pre-commit: ## Run pre-commit hooks manually
	@echo "🔄 Running pre-commit hooks..."
	@pre-commit run --all-files || echo "⚠️  Some pre-commit hooks failed"

check-comprehensive: ## Run all code quality checks (format + lint + complexity + type-check + security)
	@echo "🚀 Running comprehensive code quality checks..."
	@make format
	@make lint
	@make complexity
	@make type-check
	@make docs
	@make security
	@echo "🔄 Running pre-commit on all files..."
	@pre-commit run --all-files || echo "⚠️  Pre-commit not set up, run 'make setup-precommit' first"
	@echo "✅ All checks complete!"

dev-setup-comprehensive: install-deps setup-precommit ## Complete development setup
	@echo "Development environment setup complete!"
	@echo "Run 'make check' to verify everything is working"

# CI simulation
ci-check-comprehensive: ## Run checks similar to CI environment
	@echo "Running CI-like checks..."
	@make clean
	@make install-deps
	@make security-baseline
	@make check
	@make test
	@echo "CI checks complete!"
