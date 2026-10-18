# Authenticator demo requirements

The former complete privacyIDEA/MySQL/web-wallet demo instructions are retired.
This repository's Docker Compose file currently starts only a code-server
workspace, not the authentication backend or a working browser wallet.

Retain the demo's enrollment QR, OTP generation/verification, custom-token
challenge-response, plugin reload and API interoperability requirements in
[Docker development ownership](docker/README.md). Use [development checks](docs/development-checks.md)
for the current Flutter commands and the unfinished browser/device test gates.
No completed backend, seeded users, realm, plugin or persistent database is
established by the old demo documentation. App feature sources remain unchanged.
