.PHONY: help setup-precommit install-deps dev-setup dev-setup-comprehensive format lint analyze type-check complexity docs check check-comprehensive test test-device-smoke test-live-credential test-live-presentation security security-baseline pre-commit precommit-run precommit-update quality-gate ci-check ci-check-comprehensive clean flutter-doctor build-android build-ios

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

test-device-smoke: ## Run native smoke/rejection checks on a fresh Android/iOS app (DEVICE_ID required)
	@test -n "$(DEVICE_ID)" || { echo 'Set DEVICE_ID to an explicit isolated Android/iOS device from flutter devices.' >&2; exit 2; }
	flutter test $(FLUTTER_DEVICE_SMOKE_FLAGS) integration_test/installed_wallet_smoke_test.dart \
		--flavor netknights_debug -d "$(DEVICE_ID)" \
		--dart-define=WALLET_DEVICE_SMOKE=true \
		--dart-define=QR_CODE=WALLET_DEVICE_SMOKE_CAMERA_DISABLED

test-live-credential: ## Run the live credential QR integration test
	@test -f integration_test/real_credential_flow_test.dart || { echo 'The live credential suite is absent; no demo service was contacted. See docs/development-checks.md.' >&2; exit 2; }
	@QR_CODE=$$(node scripts/fetch_live_qr.js) && test -n "$$QR_CODE" && \
	flutter test integration_test/real_credential_flow_test.dart --dart-define=QR_CODE="$$QR_CODE"

test-live-presentation: ## Run the live presentation QR integration test
	@test -f integration_test/real_presentation_flow_test.dart || { echo 'The live presentation suite is absent; no demo service was contacted. See docs/development-checks.md.' >&2; exit 2; }
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
