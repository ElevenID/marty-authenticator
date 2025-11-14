#!/bin/bash

# Firebase Project Setup for Local Development
# This script helps set up a test Firebase project for FCM testing

echo "🔥 Firebase Project Setup for Local FCM Testing"
echo "=============================================="
echo ""

echo "Since Firebase Cloud Messaging cannot be emulated locally,"
echo "you need a real Firebase project for testing. Here's how:"
echo ""

echo "1. CREATE FIREBASE PROJECT:"
echo "   - Go to https://console.firebase.google.com"
echo "   - Click 'Add project'"
echo "   - Name: 'privacyidea-auth-test' (or similar)"
echo "   - Disable Google Analytics (optional for testing)"
echo ""

echo "2. ENABLE CLOUD MESSAGING:"
echo "   - In your project, go to 'Project settings' > 'Cloud Messaging'"
echo "   - Note your Server Key and Sender ID"
echo ""

echo "3. ADD iOS APP:"
echo "   - Click 'Add app' > iOS"
echo "   - Bundle ID: 'privacyidea.authenticator' (match your app)"
echo "   - Download GoogleService-Info.plist"
echo ""

echo "4. GENERATE FLUTTER FIREBASE CONFIG:"
echo "   - Install Firebase CLI: npm install -g firebase-tools"
echo "   - Install FlutterFire CLI: dart pub global activate flutterfire_cli"
echo "   - Run: flutterfire configure --project=YOUR_PROJECT_ID"
echo ""

echo "5. REPLACE PLACEHOLDER CONFIG:"
echo "   - The command above will generate proper firebase_options.dart"
echo "   - Replace the DEFAULT_FIREBASE_* values with real ones"
echo ""

echo "📋 Current placeholder values that need replacement:"
echo "   - DEFAULT_FIREBASE_API_KEY"
echo "   - DEFAULT_FIREBASE_APP_ID"
echo "   - DEFAULT_FIREBASE_MESSAGING_SENDER_ID"
echo "   - DEFAULT_FIREBASE_PROJECT_ID"
echo "   - DEFAULT_FIREBASE_STORAGE_BUCKET"
echo "   - DEFAULT_FIREBASE_IOS_CLIENT_ID"
echo "   - DEFAULT_FIREBASE_IOS_BUNDLE_ID"
echo ""

echo "🚀 After setup, FCM will work with your iOS simulator!"
echo "   You'll be able to:"
echo "   - Get FCM tokens"
echo "   - Receive push notifications"
echo "   - Test messaging workflows"
echo ""

echo "💡 Alternative: For pure local development without FCM,"
echo "   you can mock the FCM responses in your code."