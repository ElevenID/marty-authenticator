# Demo Mode Entry Points

This project includes multiple demo main entry points for testing different mDoc credential scenarios. Each demo mode loads specific credentials to facilitate UI testing and development.

## Available Demo Modes

### 1. MDL Only (`main_demo_mdl.dart`)
**Purpose**: Test with a single Mobile Driver License credential

**Credentials Loaded**:
- Mobile Driver License (mDL) - Valid state

**Run Command**:
```bash
flutter run -t lib/main_demo_mdl.dart -d chrome
```

**Use Case**: Minimal credential testing, verifying single credential display and interactions.

---

### 2. MDL + Passport (`main_demo_mdl_passport.dart`)
**Purpose**: Test with two common travel document types

**Credentials Loaded**:
- Mobile Driver License (mDL) - Valid state
- Mobile Passport (mPassport) - Valid state

**Run Command**:
```bash
flutter run -t lib/main_demo_mdl_passport.dart -d chrome
```

**Use Case**: Testing credential selection, multiple credential display, and switching between credentials.

---

### 3. All mDoc Types (`main_demo_all_mdocs.dart`)
**Purpose**: Test with all available mDoc credential types

**Credentials Loaded**:
- Mobile Driver License (mDL) - Valid state
- Mobile Passport (mPassport) - Valid state
- Mobile ID (mID) - Valid state

**Run Command**:
```bash
flutter run -t lib/main_demo_all_mdocs.dart -d chrome
```

**Use Case**: Comprehensive testing of all credential types, UI layouts with multiple credentials, and credential type-specific features.

---

### 4. mDocs Multiple States (`main_demo_mdocs_states.dart`)
**Purpose**: Test credential state handling (valid, expiring, expired)

**Credentials Loaded**:
- MDL (Valid) - Currently valid credential
- Passport (Valid) - Currently valid credential
- MDL (Near Expiry) - Expires within 7 days
- Mobile ID (Near Expiry) - Expires within 7 days
- Passport (Expired) - Recently expired credential

**Run Command**:
```bash
flutter run -t lib/main_demo_mdocs_states.dart -d chrome
```

**Use Case**: Testing UI warnings for expiring credentials, expired credential handling, and state-based visual indicators.

---

## Running Demos

### Command Line

Run any demo mode using the Flutter CLI:

```bash
# MDL Only
flutter run -t lib/main_demo_mdl.dart -d chrome

# MDL + Passport
flutter run -t lib/main_demo_mdl_passport.dart -d chrome

# All mDoc Types
flutter run -t lib/main_demo_all_mdocs.dart -d chrome

# Multiple States
flutter run -t lib/main_demo_mdocs_states.dart -d chrome
```

### VS Code Launch Configurations

Press **F5** or use the **Run and Debug** panel, then select one of the demo configurations:

- Demo: MDL Only
- Demo: MDL + Passport
- Demo: All mDoc Types
- Demo: mDocs Multiple States

### Supported Platforms

Each demo can run on:
- **Chrome** (Web): `-d chrome`
- **macOS**: `-d macos`
- **Android**: `-d android` (requires Android emulator/device)
- **iOS**: `-d ios` (requires iOS simulator/device, macOS only)

---

## Architecture

### Base Configuration (`lib/mains/demo_base.dart`)

All demo entry points use a shared base configuration that provides:

- Mock SpruceID services setup
- Firebase configuration (optional)
- Mock QR scanner setup
- Credential-first main view routing
- Consistent app structure

### Credential Loading Pattern

Each demo defines a `CredentialsLoader` function that:

1. Creates mock mDoc credentials using `MDocFixtures`
2. Stores credentials in the mock mDoc manager
3. Returns a list of loaded credential names for logging

Example:
```dart
credentialsLoader: (mockServices) async {
  final mdl = MDocFixtures.mobileDriverLicense(state: CredentialState.valid);
  await mockServices.mdocManager.storeCredential('demo-mdl-001', mdl);
  return ['Mobile Driver License (mDL)'];
}
```

---

## Creating New Demo Modes

To add a new demo mode:

1. **Create a new main file** in `lib/` (e.g., `main_demo_custom.dart`)

2. **Use the demo base pattern**:
```dart
import 'mains/demo_base.dart';
import 'fixtures/spruce_credentials_fixtures.dart';

void main() async {
  await runDemoApp(
    demoName: 'Your Demo Name',
    credentialsLoader: (mockServices) async {
      // Load your credentials here
      final credential = MDocFixtures.yourCredential();
      await mockServices.mdocManager.storeCredential('id', credential);
      return ['Credential Name'];
    },
  );
}
```

3. **Add VS Code launch configuration** in `.vscode/launch.json`:
```json
{
  "name": "Demo: Your Demo Name",
  "request": "launch",
  "type": "dart",
  "program": "lib/main_demo_custom.dart"
}
```

---

## Features Available in Demo Mode

All demo modes include:

- ✅ Mock SpruceID services (credentials work without backend)
- ✅ Mock QR scanner with fixture selection
- ✅ Credential-first main view (shows credentials immediately)
- ✅ Full navigation (settings, credential details, etc.)
- ✅ Hot reload support
- ✅ Firebase optional (disabled by default)

---

## Troubleshooting

### Demo mode not loading credentials

**Check console logs** for:
- `🎭 DEMO MODE: [Your Demo Name] 🎭`
- `✅ Loaded: [Credential Name]`

If credentials aren't loading, verify:
1. Mock services are initialized
2. Credential fixtures are created correctly
3. Credentials are stored in the mock manager

### UI not showing credentials

Verify that:
1. The app is using `WalletLandingView` with `CredentialsList` (check `demo_base.dart`)
2. Mock providers are overridden correctly in `AppWrapper`
3. The credential manager is reading from the correct storage

---

## Related Files

- **Demo Base**: `lib/mains/demo_base.dart`
- **Credential Fixtures**: `lib/fixtures/spruce_credentials_fixtures.dart`
- **Mock Services**: `lib/mocks/mock_spruce_services.dart`
- **Mock QR Scanner**: `lib/mocks/mock_qr_scanner_service.dart`
- **Credential Views**: `lib/views/main_view/credential_first_main_view.dart`
