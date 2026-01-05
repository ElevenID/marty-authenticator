# Push Notification Configuration

This directory contains the Docker configuration for the Marty Authenticator, including push notification integration.

## Push Notification Options

The Marty Authenticator supports multiple push notification methods:

1. **SSE (Server-Sent Events)** - Real-time push for web development and testing
2. **Polling** - Fallback when SSE/FCM is unavailable
3. **FCM (Firebase Cloud Messaging)** - Production mobile push notifications

## Web Development with SSE

For web development and testing, SSE provides real-time push notifications without Firebase:

```bash
# Start the development stack
cd docker
docker-compose up -d

# Run the Flutter web app
flutter run -d chrome
```

The Flutter app automatically uses SSE on web when `USE_SSE_PUSH=true` (default).

## Mobile Development with FCM

For mobile app development with Firebase push notifications:

1. **Copy the environment template:**

   ```bash
   cp docker/.env.example docker/.env
   ```

2. **Add your Firebase credentials to `docker/.env`:**
   - Get your Firebase configuration from the [Firebase Console](https://console.firebase.google.com)
   - Update the values in `docker/.env` with your actual credentials

3. **Start the containers:**

   ```bash
   cd docker
   docker-compose up -d
   ```

4. **Run the mobile app:**
   ```bash
   flutter run -d <device-id>
   ```

## Environment Variables

### Push Configuration

- `USE_SSE_PUSH` - Enable SSE for web push (default: `true`)
- `POLL_INTERVAL_MS` - Polling interval in milliseconds (default: `5000`)
- `MARTY_API_URL` - Marty backend API URL

### Firebase Configuration (Mobile Only)

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
