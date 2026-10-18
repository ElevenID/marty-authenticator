# Push configuration ownership and unfinished requirements

The local Compose file starts only the code-server workspace. It does not
configure a Marty push backend or load Firebase settings into the Flutter app.
Copying `docker/.env.example` and restarting that container does not establish
mobile FCM or browser SSE delivery. The former `setup-firebase-project.sh`
instructions referenced an absent script.

The template retains historical project, sender, storage, Android, iOS and web
configuration fields, plus a server-side configuration-file path. Current
Compose and Dart sources do not consume those environment names. iOS project
metadata still contains Firebase references; neither those references nor this
template prove a configured notification integration. No platform metadata,
configuration value or existing app behavior is removed by this correction.

## Retained push requirements

Select an explicit Rust backend and app adapter, then qualify:

- authenticated SSE delivery for browser development, reconnection and bounded
  network failures, without requiring a Firebase emulator;
- a documented polling fallback, interval configuration and behavior when SSE or
  FCM is unavailable;
- native Android/iOS FCM registration, permissions, token refresh and revocation,
  foreground/background delivery and app lifecycle behavior;
- explicit project and platform application/sender identifiers, storage/auth
  settings where required, and controlled server-side credential delivery;
- endpoint and transport selection rather than assuming `USE_SSE_PUSH`,
  `POLL_INTERVAL_MS` or `MARTY_API_URL` are automatically wired into this template;
- consented OTP/PUSH and enrollment flows against the selected backend, including
  rejection, expired/invalid credentials and disconnected clients;
- isolated positive/negative delivery tests through the real app and backend.

Keep developer credentials outside Git and separate from production secret
provisioning. Choosing a supported SDK and configuration owner is unfinished;
these requirements do not declare FCM, polling or SSE feature parity.

See [Docker ownership](README.md) for the actual local workspace and
[development checks](../docs/development-checks.md) for the missing browser test
entrypoint and device integration acceptance requirements.
