# Historical development network notes

The PrivacyIDEA/Firebase topology and SSI Python bindings described in this old
setup are retired. Current `docker-compose.yml` exposes only the plugin-dev
convenience service; it does not build or install `ssi_python`. Do not use these
notes as a current deployment or successful-integration claim. The app uses
Marty with SSE, its native Rust bridge and platform SDK handlers.

For active development use [the Docker README](README.md) and the checked-in
Compose/Dockerfiles. The unfinished issuer-side feature is retained in
[Python issuer integration](../docs/python-issuer-integration.md); it requires a
real consuming service and independent protocol acceptance before deployment.
