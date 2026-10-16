.PHONY: help setup-precommit install-deps dev-setup dev-setup-comprehensive format lint analyze type-check complexity docs check check-comprehensive test test-live-credential test-live-presentation security security-baseline pre-commit precommit-run precommit-update quality-gate ci-check ci-check-comprehensive clean flutter-doctor build-android build-ios

help: ## Show developer commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-24s %s\n", $$1, $$2}'

setup-precommit: ## Install the repository hooks using an existing pre-commit installation
	@bash scripts/setup-precommit.sh

install-deps: ## Restore the declared Flutter and live-QR helper dependencies
	flutter pub get
	npm ci

dev-setup dev-setup-comprehensive: install-deps setup-precommit ## Set up development dependencies and hooks

format: ## Format Dart source
	dart format .

lint analyze type-check complexity: ## Run the Flutter analyzer
	flutter analyze

docs: ## Check Markdown links with the configured hook
	pre-commit run markdown-link-check --all-files

check check-comprehensive quality-gate: lint pre-commit ## Run analysis and repository hooks

test: ## Run Flutter tests
	flutter test

test-live-credential: ## Run the live credential QR integration test
	@QR_CODE=$$(node scripts/fetch_live_qr.js) && test -n "$$QR_CODE" && \
	flutter test integration_test/real_credential_flow_test.dart --dart-define=QR_CODE="$$QR_CODE"

test-live-presentation: ## Run the live presentation QR integration test
	@QR_CODE=$$(node scripts/fetch_live_presentation_qr.js) && test -n "$$QR_CODE" && \
	flutter test integration_test/real_presentation_flow_test.dart -d macos --dart-define=QR_CODE="$$QR_CODE"

security: ## Run the pinned secret-scanning hook
	pre-commit run gitleaks --all-files

security-baseline: security ## Compatibility alias; scans without generating a baseline

pre-commit precommit-run: ## Run the repository hooks and propagate failures
	pre-commit run --all-files

precommit-update: ## Update hook pins for review
	pre-commit autoupdate

ci-check ci-check-comprehensive: check test ## Run local analysis, hooks and tests

clean: ## Remove Flutter build output
	flutter clean

flutter-doctor: ## Check the Flutter environment
	flutter doctor

build-android: ## Build the Android APK
	flutter build apk

build-ios: ## Build iOS on macOS
	flutter build ios
