# Docker development ownership

`docker-compose.yml` currently defines only `plugin-dev`, a code-server
workspace on port 8443 with mounts for local plugin directories. It does not
start a privacyIDEA server, MySQL database, demo token, realm, or Flutter wallet.
The mounts preserve the intended editing workspace; no bundled plugin source or
backend startup qualification is implied.

From the repository root, operate only that declared Compose project:

```bash
docker compose -f docker/docker-compose.yml config --services
docker compose -f docker/docker-compose.yml up -d plugin-dev
docker compose -f docker/docker-compose.yml logs plugin-dev
docker compose -f docker/docker-compose.yml down
```

The orphan `scripts/plugin-dev.sh`, `docker/test-setup.sh` and
`docker/entrypoint.sh` are retired. They assumed absent privacyIDEA services,
initialization, plugins and database state. The helper also resolved its paths
under `scripts/docker/` and its cleanup command pruned unrelated Docker state.
No app source, Compose service, environment example, platform config or data is
removed by retiring these tools. Avoid recreating a Python backend solely to
make old demo scripts pass; current Marty service behavior belongs to Rust.

## Unfinished plugin and demo interoperability

Choose an explicit supported backend and extension owner before implementing:

- custom authentication tokens, event handlers/automation and user resolvers;
- a real example token with QR enrollment, challenge-response and app integration;
- isolated test users/realms and actual admin/auth, token and user API operations;
- Flutter enrollment, OTP generation/verification and PUSH behavior against that
  selected backend, including rejection and network/lifecycle cases;
- edit/reload/log/status workflows and health checks that exercise the selected
  implementation rather than merely detect an IDE or HTTP response;
- persistent test storage, repeatable initialization and schema upgrades with
  explicit credentials/configuration and bounded startup errors;
- cleanup scoped to disposable project resources, preserving unrelated data.

Prove these through isolated positive/negative integration tests and actual app
startup before claiming a complete demo. Legacy privacyIDEA API paths and seeded
credentials in Git history are not the current Marty Rust service contract.
Existing Flutter OTP/PUSH and enrollment code remain supported source owners;
this tooling retirement does not remove or establish backend feature parity.

For the separate browser-wallet image and missing E2E bridge requirements, see
[development checks](../docs/development-checks.md). Production and test Docker
recipes remain distinct from this code-server Compose workspace.
