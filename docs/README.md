# Marty Authenticator documentation

The [root README](../README.md) remains the entry point for supported app scope, build commands, release-signing limitations, and contribution guidance.

## Development and testing

- [Development checks](development-checks.md) — current test commands and unfinished device/browser coverage.
- [Development ownership](development/PROJECT_README.md) — app versus workspace/backend responsibilities.
- [Demo requirements and limitations](development/DEMO_README.md) — retained requirements, not a working backend demonstration.
- [Docker development ownership](../docker/README.md) — the scope of the code-server workspace.

## Integrations

- [Integration guide index and scope](integrations/README.md)
- [Deep-link quick reference](integrations/DEEP_LINKING_QUICK_REFERENCE.md)
- [Deep linking](integrations/DEEP_LINKING.md)
- [Native SpruceID integration ownership](spruceid-integration.md)
- [SpruceKit SDK integration notes](integrations/SPRUCEKIT_SDK_INTEGRATION.md)
- [Unfinished Python issuer integration requirements](python-issuer-integration.md)

## UI reference and project notes

- [Vertical stacked cards implementation](reference/VERTICAL_STACKED_CARDS_README.md)
- [Demo mode entry-point notes](project/README_DEMO_MODES.md)

These implementation and demo notes are retained for context. Their historical test or feature statements are not new verification results; use the current development checks and actual source tree before relying on a demo command.

## File-placement conventions

Put integration guidance in `docs/integrations/`, development guidance in `docs/development/`, implementation references in `docs/reference/`, and project/history notes in `docs/project/`. Link important documents from this index instead of adding another root-level README variant. Commands and plain code paths in the moved guides are still relative to the repository root unless explicitly stated otherwise.

Keep `README.md`, `LICENSE`, `PRIVACY.md`, `CHANGELOG.md`, Flutter manifests, platform directories, Rust configuration, and tool-discovered files at their supported paths. Deep-linking and SDK notes are grouped in `docs/integrations/`; current native ownership guidance remains at `docs/spruceid-integration.md`. No app, native bridge, build, signing, or deployment changes are part of this organization work.
