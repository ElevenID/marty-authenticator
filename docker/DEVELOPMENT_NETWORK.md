# Docker Development Network Setup

This Docker Compose setup creates a complete development environment for the Marty Authenticator with:

## Services

### 1. Firebase Emulator (`firebase`)

- **Purpose**: Mock Firebase services for local development
- **Ports**:
  - `4000`: Emulator Suite UI (http://localhost:4000)
  - `9099`: Authentication emulator
  - `8081`: Cloud Firestore emulator
  - `9000`: Realtime Database emulator
  - `5001`: Cloud Functions emulator
  - `9199`: Cloud Storage emulator
  - `8085`: Firebase Hosting emulator
  - `9299`: Pub/Sub emulator

### 2. PrivacyIDEA Server (`privacyidea`)

- **Purpose**: Token authentication server with SSI Python bindings
- **Port**: `8080`
- **Admin Login**: `admin` / `admin`
- **Features**:
  - OID4VC event handler with mDoc support
  - SSI Python bindings (MdocIssuer, DidManager, Oid4VciIssuer)
  - Custom event handlers for credential issuance

### 3. MySQL Database (`mysql`)

- **Purpose**: Backend database for PrivacyIDEA
- **Port**: `3306`
- **Credentials**: `pi_user` / `pi_password`

### 4. Authenticator Web App (`authenticator-web`)

- **Purpose**: Flutter web app for the authenticator
- **Port**: `8888` (http://localhost:8888)
- **Configuration**:
  - Connected to Firebase emulators
  - Connected to PrivacyIDEA server
  - Network-accessible for testing credential flows

### 5. Plugin Development Server (`plugin-dev`)

- **Purpose**: VS Code server for plugin development
- **Port**: `8443` (http://localhost:8443)
- **Password**: `developer`

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Network                           │
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Firebase   │◄────►│ Authenticator│                     │
│  │   Emulator   │      │   Web App    │                     │
│  │              │      │              │                     │
│  │  :4000-9299  │      │    :8888     │                     │
│  └──────────────┘      └──────┬───────┘                     │
│         ▲                     │                              │
│         │                     ▼                              │
│         │              ┌──────────────┐                     │
│         └─────────────►│ PrivacyIDEA  │                     │
│                        │   Server     │                     │
│                        │   + SSI      │                     │
│                        │    :8080     │                     │
│                        └──────┬───────┘                     │
│                               │                              │
│                               ▼                              │
│                        ┌──────────────┐                     │
│                        │    MySQL     │                     │
│                        │    :3306     │                     │
│                        └──────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## Getting Started

### 1. Start All Services

```bash
cd docker
docker compose up -d
```

### 2. Initialize PrivacyIDEA

```bash
docker compose exec privacyidea bash -c "
  pi-manage create_enckey && \
  pi-manage create_audit_keys && \
  pi-manage create_tables && \
  pi-manage admin add admin -e admin@localhost -p admin
"
```

### 3. Access Services

- **Authenticator App**: http://localhost:8888
- **PrivacyIDEA Admin**: http://localhost:8080 (`admin` / `admin`) # pragma: allowlist secret
- **Firebase Emulator UI**: http://localhost:4000
- **Plugin Dev Server**: http://localhost:8443 (password: `developer`) # pragma: allowlist secret

## Development Workflow

### Testing Credential Issuance

1. **Configure Event Handler in PrivacyIDEA**:
   - Login to http://localhost:8080
   - Navigate to: Config → Event Handlers
   - Create new handler:
     - Type: `OID4VC`
     - Action: `issue_mdoc_driver_license` or `issue_mdoc_identity`
     - Options:
       - `issuer_url`: `http://privacyidea:8080`
       - `issuer_did`: (generate via `generate_issuer_did` action)

2. **Test in Authenticator App**:
   - Open http://localhost:8888
   - App is configured to use Firebase emulator
   - App can communicate with PrivacyIDEA at `http://privacyidea:8080`

3. **Monitor Firebase**:
   - Open http://localhost:4000
   - View authentication, Firestore, and other emulated services

### Testing Network Connectivity

```bash
# Test from authenticator to PrivacyIDEA
docker compose exec authenticator-web curl http://privacyidea:8080/

# Test from authenticator to Firebase
docker compose exec authenticator-web curl http://firebase:4000/

# Test from PrivacyIDEA (verify SSI bindings)
docker compose exec privacyidea python3 -c "
import ssi_python
from privacyidea.lib.eventhandler.custom.oid4vc_handler import OID4VCEventHandler
print('SSI Bindings:', ', '.join([x for x in dir(ssi_python) if not x.startswith('_')]))
handler = OID4VCEventHandler()
print('Handler Actions:', len(handler.actions))
"
```

## Plugin Development

### Modify Event Handler

The event handler is mounted as a volume, so changes take effect after container restart:

```bash
# Edit the handler
vim plugins/custom-eventhandlers/oid4vc_handler.py

# Restart to pick up changes
docker compose restart privacyidea

# Test changes
docker compose exec privacyidea python3 /path/to/test_handler.py
```

### Modify Flutter App

The Flutter app needs to be rebuilt when code changes:

```bash
# Rebuild the app
docker compose build authenticator-web

# Restart the container
docker compose up -d authenticator-web
```

## Troubleshooting

### Check Service Status

```bash
docker compose ps
docker compose logs firebase
docker compose logs privacyidea
docker compose logs authenticator-web
```

### Reset Everything

```bash
docker compose down -v
docker compose up -d
# Re-initialize PrivacyIDEA (see step 2 above)
```

### Firebase Emulator Not Starting

If using the `spine3/firebase-emulator` image doesn't work, you can build a custom one:

```bash
# Create Dockerfile.firebase
cat > Dockerfile.firebase <<EOF
FROM node:18-alpine
RUN npm install -g firebase-tools
WORKDIR /firebase
CMD ["firebase", "emulators:start", "--project", "demo-project"]
EOF

# Update docker-compose.yml to build from this Dockerfile
```

## Environment Variables

The app receives these variables at build time:

- `USE_FIREBASE_EMULATOR=true`
- `FIREBASE_AUTH_EMULATOR_HOST=firebase:9099`
- `FIRESTORE_EMULATOR_HOST=firebase:8081`
- `PRIVACYIDEA_URL=http://privacyidea:8080`

Access them in Dart with:

```dart
const bool useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const String privacyideaUrl = String.fromEnvironment('PRIVACYIDEA_URL');
```

## Next Steps

1. ✅ All services running
2. ✅ Network communication working
3. 🔄 Configure app to read environment variables
4. 🔄 Implement credential offer flow
5. 🔄 Test end-to-end mDoc issuance
