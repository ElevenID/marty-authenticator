/*
 * privacyIDEA Authenticator
 *
 * Author: Frank Merkel <frank.merkel@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:mutex/mutex.dart';
import 'package:privacyidea_authenticator/repo/secure_storage.dart';
import 'package:privacyidea_authenticator/utils/utils.dart';

import '../../../../../../../utils/view_utils.dart';
import 'globals.dart';
import 'identifiers.dart';
import 'logger.dart';

class FirebaseUtils {
  static FirebaseUtils? _instance;
  final Mutex _initFbMutex = Mutex();
  bool initializedFirebase = false;
  final Mutex _initHandlerMutex = Mutex();
  bool initializedHandler = false;

  // ###########################################################################
  // FIREBASE CONFIG
  // ###########################################################################
  static const FIREBASE_TOKEN_KEY_PREFIX_LEGACY =
      GLOBAL_SECURE_REPO_PREFIX_LEGACY;
  static const CURRENT_APP_TOKEN_KEY_LEGACY = 'CURRENT_APP_TOKEN';
  static const NEW_APP_TOKEN_KEY_LEGACY = 'NEW_APP_TOKEN';

  static const FIREBASE_TOKEN_KEY_PREFIX =
      '${GLOBAL_SECURE_REPO_PREFIX}_firebase';
  static const CURRENT_APP_TOKEN_KEY = 'current';
  static const NEW_APP_TOKEN_KEY = 'new';

  final SecureStorage _storageLegacy;
  final SecureStorage _storage;

  FirebaseUtils._({SecureStorage? storage, SecureStorage? legacyStorage})
    : _storage =
          storage ??
          SecureStorage(
            storagePrefix: FIREBASE_TOKEN_KEY_PREFIX,
            storage: SecureStorage.defaultStorage,
          ),
      _storageLegacy =
          legacyStorage ??
          SecureStorage(
            storagePrefix: FIREBASE_TOKEN_KEY_PREFIX_LEGACY,
            storage: SecureStorage.legacyStorage,
          );

  factory FirebaseUtils({
    SecureStorage? storage,
    SecureStorage? legacyStorage,
  }) {
    if (storage != null || legacyStorage != null) {
      // For testing, return a new instance with mocked storage
      return FirebaseUtils._(storage: storage, legacyStorage: legacyStorage);
    }
    if (_instance != null) return _instance!;
    if (deviceHasFirebaseMessaging) {
      _instance ??= FirebaseUtils._();
    } else {
      _instance ??= NoFirebaseUtils();
    }

    return _instance!;
  }

  /// Configure Firebase emulators based on environment variables
  void _configureFirebaseEmulators() {
    const useEmulator = bool.fromEnvironment(
      'USE_FIREBASE_EMULATOR',
      defaultValue: false,
    );

    if (useEmulator) {
      const authEmulatorHost = String.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_HOST',
        defaultValue: 'localhost:9099',
      );

      Logger.info('Firebase emulator configuration enabled');
      Logger.info('Auth emulator: $authEmulatorHost');

      // Note: Firebase Auth emulator configuration would go here
      // However, FirebaseAuth emulator configuration requires firebase_auth package
      // which is not included in this app since it only uses FCM.
      // For FCM testing, the emulator configuration is handled by the Firebase emulator suite
      // and the app connects to it automatically when running in emulator mode.
    }
  }

  /// Must be used in the main method before runApp() is called.
  /// Returns null if Firebase is disabled or not configured.
  Future<FirebaseApp?> initializeApp() async {
    await _initFbMutex.acquire();
    try {
      if (initializedFirebase) {
        Logger.warning('Firebase already initialized');
        _initFbMutex.release();
        return null;
      }

      // Check if Firebase is configured and enabled
      if (appFirebaseOptions == null) {
        Logger.info(
          'Firebase is disabled - skipping Firebase app initialization',
        );
        initializedFirebase = true; // Mark as "initialized" to prevent retries
        _initFbMutex.release();
        return null;
      }

      final FirebaseOptions options = appFirebaseOptions!;
      final app = await Firebase.initializeApp(
        name: "fb-${options.projectId}",
        options: options,
      );
      await app.setAutomaticDataCollectionEnabled(false);

      // Configure Firebase emulators if environment variables are set
      _configureFirebaseEmulators();

      initializedFirebase = true;
      assert(
        app.isAutomaticDataCollectionEnabled == false,
        'Automatic data collection should be disabled',
      );
      _initFbMutex.release();
      return app;
    } catch (e, s) {
      _initFbMutex.release();
      Logger.error(
        'Error while initializing Firebase',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// This method sets up the Firebase messaging handler for the app. It must be called after initializeApp().
  /// Returns early if Firebase is disabled or not configured.
  Future<void> setupHandler({
    required Future<void> Function(RemoteMessage) foregroundHandler,
    required Future<void> Function(RemoteMessage) backgroundHandler,
    required dynamic Function({String? firebaseToken}) updateFirebaseToken,
  }) async {
    await _initFbMutex.acquire();
    if (!initializedFirebase) {
      Logger.error('Initialize Firebase before setting up the handler');
      _initFbMutex.release();
      return;
    }

    // Check if Firebase is actually configured and available
    if (appFirebaseOptions == null) {
      Logger.info('Firebase is disabled - skipping handler setup');
      _initFbMutex.release();
      return;
    }
    _initFbMutex.release();
    await _initHandlerMutex.acquire();
    if (initializedHandler) {
      Logger.warning('Firebase handler already initialized');
      return;
    }

    Logger.info('FirebaseUtils: Initializing Firebase');

    FirebaseMessaging.onMessage.listen(foregroundHandler);
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);

    try {
      String? firebaseToken = await getFBToken();

      if (firebaseToken != await getCurrentFirebaseToken() &&
          firebaseToken != null) {
        updateFirebaseToken(firebaseToken: firebaseToken);
      }
    } catch (error, stackTrace) {
      if (error is PlatformException) {
        if (error.code == FIREBASE_TOKEN_ERROR_CODE) return; // ignore
        showErrorStatusMessage(
          message: (l) => l.pushInitializeUnavailable,
          details: (_) =>
              '${error.code}: ${error.message ?? 'no error message'}',
        );
      }
      if (error is FirebaseException) {
        if (error.code == FIREBASE_TOKEN_ERROR_CODE) return; // ignore
        showErrorStatusMessage(
          message: (l) => l.pushInitializeUnavailable,
          details: (_) =>
              '${error.code}: ${error.message ?? 'no error message'}',
        );
      }

      Logger.error(
        'Unknown Firebase error',
        error: error,
        stackTrace: stackTrace,
      );
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      if ((await getCurrentFirebaseToken()) != newToken) {
        await setNewFirebaseToken(newToken);
        // TODO what if this fails, when should a retry be attempted?
        try {
          updateFirebaseToken(firebaseToken: newToken);
        } catch (error, stackTrace) {
          Logger.error(
            'Error updating firebase token',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    });

    initializedHandler = true;
    _initHandlerMutex.release();
  }

  /// Returns the current firebase token of the app / device. Throws a
  /// PlatformException with a custom error code if retrieving the firebase
  /// token failed. This may happen if, e.g., no network connection is available.
  /// Returns NO_FIREBASE_TOKEN if Firebase is disabled.
  Future<String?> getFBToken() async {
    // Check if Firebase is configured and available
    if (appFirebaseOptions == null) {
      Logger.info('Firebase is disabled - returning NO_FIREBASE_TOKEN');
      return NoFirebaseUtils.NO_FIREBASE_TOKEN;
    }

    String? firebaseToken;
    try {
      firebaseToken = await FirebaseMessaging.instance.getToken();
      // Temporary logging for debugging FCM
      if (firebaseToken != null) {
        Logger.info('FCM Token retrieved: $firebaseToken');
      } else {
        Logger.warning('FCM Token is null');
      }
    } on FirebaseException catch (e, s) {
      String errorMessage = e.message ?? 'no error message';
      Logger.warning(
        'Unable to retrieve Firebase token! ($errorMessage: ${e.code})',
        error: e,
        stackTrace: s,
      );
    }

    // Fall back to the last known firebase token
    if (firebaseToken == null) {
      firebaseToken = await getCurrentFirebaseToken();
    } else {
      Logger.info('New Firebase token retrieved');
      await setNewFirebaseToken(firebaseToken);
    }

    if (firebaseToken == null) {
      // This error should be handled in all cases, the user might be informed
      // in the form of a pop-up message.
      throw PlatformException(
        message:
            'Firebase token could not be retrieved, the only know cause of this is'
            ' that the firebase servers could not be reached.',
        code: FIREBASE_TOKEN_ERROR_CODE,
      );
    }

    return firebaseToken;
  }

  Future<bool> deleteFirebaseToken() async {
    Logger.info('Deleting firebase token..');
    try {
      final app = await Firebase.initializeApp();
      await app.setAutomaticDataCollectionEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
      Logger.warning('Firebase token deleted from Firebase');
    } on FirebaseException catch (e) {
      if (e.message?.contains('IOException') == true) {
        throw SocketException(e.message!);
      }
      rethrow;
    }
    await _storage.delete(key: CURRENT_APP_TOKEN_KEY);
    await _storage.delete(key: NEW_APP_TOKEN_KEY);
    Logger.info('Firebase token deleted from secure storage');
    return true;
  }

  Future<void> setCurrentFirebaseToken(String str) {
    Logger.info('Setting current firebase token');
    return _storage.write(key: CURRENT_APP_TOKEN_KEY, value: str);
  }

  Future<String?> getCurrentFirebaseToken() async {
    final current = await _storage.read(key: CURRENT_APP_TOKEN_KEY);
    if (current != null) return current;
    final legacyCurrent = await _storageLegacy.read(
      key: CURRENT_APP_TOKEN_KEY_LEGACY,
    );
    if (legacyCurrent != null) {
      Logger.info('Loaded legacy current firebase token from secure storage');
      await _storage.write(key: CURRENT_APP_TOKEN_KEY, value: legacyCurrent);
      await _storageLegacy.delete(key: CURRENT_APP_TOKEN_KEY_LEGACY);
      Logger.info(
        'Migrated legacy current firebase token to new secure storage',
      );
      return legacyCurrent;
    }
    return null;
  }

  // This is used for checking if the token was updated.
  Future<void> setNewFirebaseToken(String str) {
    Logger.info('Setting new firebase token');
    return _storage.write(key: NEW_APP_TOKEN_KEY, value: str);
  }

  Future<String?> getNewFirebaseToken() async {
    final newFbToken = await _storage.read(key: NEW_APP_TOKEN_KEY);
    if (newFbToken != null) return newFbToken;
    final legacyNewFbToken = await _storageLegacy.read(
      key: NEW_APP_TOKEN_KEY_LEGACY,
    );
    if (legacyNewFbToken != null) {
      Logger.info('Loaded legacy new firebase token from secure storage');
      await _storage.write(key: NEW_APP_TOKEN_KEY, value: legacyNewFbToken);
      await _storageLegacy.delete(key: NEW_APP_TOKEN_KEY_LEGACY);
      Logger.info('Migrated legacy new firebase token to new secure storage');
      return legacyNewFbToken;
    }
    return null;
  }
}

/// This class just is used to disable Firebase for web builds.
class NoFirebaseUtils implements FirebaseUtils {
  @override
  Mutex get _initFbMutex => Mutex();
  @override
  bool initializedFirebase = false;

  @override
  Mutex get _initHandlerMutex => Mutex();
  @override
  bool initializedHandler = false;

  @override
  Future<String> getFBToken() => Future.value(NO_FIREBASE_TOKEN);

  @override
  Future<void> setupHandler({
    required Future<void> Function(RemoteMessage p1) foregroundHandler,
    required Future<void> Function(RemoteMessage p1) backgroundHandler,
    required void Function({String? firebaseToken}) updateFirebaseToken,
  }) async {}

  @override
  Future<bool> deleteFirebaseToken() => Future.value(true);

  static const String NO_FIREBASE_TOKEN = 'no_firebase_token';

  @override
  Future<void> setCurrentFirebaseToken(String str) async {}
  @override
  Future<String?> getCurrentFirebaseToken() => Future.value(NO_FIREBASE_TOKEN);

  @override
  Future<void> setNewFirebaseToken(String str) async {}
  @override
  Future<String?> getNewFirebaseToken() => Future.value(NO_FIREBASE_TOKEN);

  @override
  Future<FirebaseApp?> initializeApp() async => null;

  /// No-op implementation for web/desktop
  @override
  void _configureFirebaseEmulators() {
    // No Firebase emulator configuration needed for NoFirebaseUtils
  }

  @override
  final SecureStorage _storage = SecureStorage(
    storagePrefix: FirebaseUtils.FIREBASE_TOKEN_KEY_PREFIX,
    storage: SecureStorage.defaultStorage,
  );

  @override
  final SecureStorage _storageLegacy = SecureStorage(
    storagePrefix: FirebaseUtils.FIREBASE_TOKEN_KEY_PREFIX_LEGACY,
    storage: SecureStorage.legacyStorage,
  );
}
