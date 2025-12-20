# Firebase Configuration Setup

This guide explains how to configure Firebase environment variables for secure development.

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Access to the Firebase project

## Setup Instructions

### 1. Copy Environment Template

```bash
cp .env.firebase.example .env.firebase
```

### 2. Retrieve Firebase Configuration

Use the Firebase CLI to get your actual configuration values:

```bash
# Get project information
firebase projects:list

# Get Android configuration
firebase apps:sdkconfig android <android-app-id>

# Get iOS configuration
firebase apps:sdkconfig ios <ios-app-id>

# Get Web configuration
firebase apps:sdkconfig web <web-app-id>
```

### 3. Fill Environment Variables

Edit `.env.firebase` with the actual values from the CLI output:

- Copy `projectId` to `FIREBASE_PROJECT_ID`
- Copy `messagingSenderId` to `FIREBASE_MESSAGING_SENDER_ID`
- Copy `storageBucket` to `FIREBASE_STORAGE_BUCKET`
- Copy platform-specific `apiKey` values
- Copy platform-specific `appId` values
- For iOS, also copy `clientId`

### 4. Build with Environment Variables

When building the Flutter app, pass the environment file:

```bash
# For Android debug build
flutter build apk --debug --flavor=netknights_debug \
  --dart-define-from-file=.env.firebase \
  --dart-define=PRIVACYIDEA_URL=http://10.0.2.2:8080

# For release builds
flutter build apk --release --flavor=netknights \
  --dart-define-from-file=.env.firebase \
  --dart-define=PRIVACYIDEA_URL=https://your-server.com
```

## Security Notes

- ✅ **DO** commit `.env.firebase.example` to version control
- ❌ **DO NOT** commit `.env.firebase` with real values
- ✅ **DO** add `.env.firebase` to `.gitignore`
- ✅ **DO** use the Firebase CLI to retrieve configuration securely

## Verification

To verify your configuration is working:

1. Build the app with environment variables (without this, Firebase will fail at runtime)
2. Install and run the app - it should validate Firebase configuration on startup
3. Check that Firebase initializes without errors in the logs
4. Verify token synchronization functions properly

### Build-time Validation

The app includes build-time validation to ensure Firebase environment variables are provided:

- **Runtime validation**: The app validates all required Firebase environment variables on startup
- **Clear error messages**: Missing variables are reported with specific instructions
- **Fail-fast approach**: App will crash immediately if Firebase configuration is invalid

If you see the error "Firebase configuration validation failed", ensure all required environment variables from `.env.firebase.example` are set in your `.env.firebase` file.

## Troubleshooting

If you encounter Firebase initialization errors:

1. Verify all required environment variables are set
2. Check that the values match your Firebase console
3. Ensure the Firebase project is active and accessible
4. Run `firebase login` if authentication issues occur
