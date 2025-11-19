# Firebase Configuration Setup

This directory contains the Docker configuration for the privacyIDEA authenticator, including Firebase Cloud Messaging (FCM) integration.

## Quick Start

1. **Copy the environment template:**
   ```bash
   cp docker/.env.example docker/.env
   ```

2. **Add your Firebase credentials to `docker/.env`:**
   - Get your Firebase configuration from the [Firebase Console](https://console.firebase.google.com)
   - Update the values in `docker/.env` with your actual credentials
   - See `setup-firebase-project.sh` for detailed setup instructions

3. **Start the containers:**
   ```bash
   cd docker
   docker-compose up -d
   ```

4. **Run the Android app:**
   ```bash
   flutter run -d <device-id>
   ```

## Firebase Configuration Files

- **`.env`** - Contains your actual Firebase credentials (git-ignored, DO NOT COMMIT)
- **`.env.example`** - Template file showing required environment variables
- **`docker-compose.yml`** - References environment variables from `.env`
- **`pi.cfg`** - privacyIDEA configuration (no hardcoded credentials)

## Environment Variables

The following Firebase variables are configured in `docker/.env`:

### Android Configuration
- `FIREBASE_PROJECT_ID` - Your Firebase project ID
- `FIREBASE_API_KEY` - Android API key
- `FIREBASE_APP_ID` - Android app ID
- `FIREBASE_MESSAGING_SENDER_ID` - FCM sender ID
- `FIREBASE_STORAGE_BUCKET` - Firebase storage bucket

### iOS Configuration
- `FIREBASE_IOS_API_KEY` - iOS API key
- `FIREBASE_IOS_APP_ID` - iOS app ID
- `FIREBASE_IOS_CLIENT_ID` - iOS client ID
- `FIREBASE_IOS_BUNDLE_ID` - iOS bundle identifier

### Web Configuration
- `FIREBASE_WEB_API_KEY` - Web API key
- `FIREBASE_WEB_APP_ID` - Web app ID
- `FIREBASE_AUTH_DOMAIN` - Firebase auth domain

## Security Notes

⚠️ **IMPORTANT**: The `docker/.env` file contains sensitive credentials and is automatically ignored by git. Never commit this file to version control.

- Always use `docker/.env.example` as a reference
- Each developer should create their own `docker/.env` file
- For production, use proper secrets management (e.g., Docker secrets, Kubernetes secrets, AWS Secrets Manager)

## Troubleshooting

### Environment variables not loading
- Ensure `docker/.env` exists (copy from `.env.example`)
- Verify the file is in the `docker/` directory
- Restart containers: `docker-compose down && docker-compose up -d`

### Firebase connection errors
- Verify your Firebase credentials are correct
- Check that your Firebase project has FCM enabled
- Ensure the app is configured in the Firebase Console

## Additional Resources

- Firebase Console: https://console.firebase.google.com
- Setup guide: `docker/setup-firebase-project.sh`
- Docker documentation: `docker/DEVELOPMENT_NETWORK.md`
