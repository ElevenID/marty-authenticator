/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
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

/// Background credential synchronization and lifecycle management service
///
/// This service provides:
/// - Automated credential status updates and revocation checking
/// - Efficient sync strategies optimized for battery life
/// - Background validation and integrity verification
/// - Intelligent scheduling based on usage patterns
/// - Network-aware synchronization with offline support

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../utils/logger.dart';
import 'sprucekit_service_extended.dart';
import 'wallet_manager_extended.dart';
import 'credential_verification_service.dart';

/// Provider for background sync service
final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService(
    spruceKitService: ref.read(spruceKitServiceExtendedProvider),
    walletManager: ref.read(walletManagerExtendedProvider),
    verificationService: ref.read(credentialVerificationServiceProvider),
  );
});

/// Synchronization strategies for different scenarios
enum SyncStrategy {
  aggressive, // Immediate sync on any change
  balanced, // Smart sync based on usage patterns
  conservative, // Minimal sync to preserve battery
  offline, // No network sync, local only
}

/// Sync operation priority levels
enum SyncPriority {
  critical, // Security-related updates (revocations)
  high, // Status updates for active credentials
  medium, // Metadata refresh for frequently used credentials
  low, // Background optimization and cleanup
}

/// Credential synchronization status
enum CredentialSyncStatus {
  upToDate, // Credential is current
  updating, // Sync in progress
  needsUpdate, // Update available
  revoked, // Credential has been revoked
  expired, // Credential has expired
  invalid, // Credential validation failed
  unknown, // Status cannot be determined
}

/// Background sync operation result
class SyncResult {
  final bool success;
  final int credentialsUpdated;
  final int revocationsDetected;
  final int errorsEncountered;
  final Duration syncDuration;
  final String? errorMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.success,
    required this.credentialsUpdated,
    required this.revocationsDetected,
    required this.errorsEncountered,
    required this.syncDuration,
    this.errorMessage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'credentialsUpdated': credentialsUpdated,
    'revocationsDetected': revocationsDetected,
    'errorsEncountered': errorsEncountered,
    'syncDurationMs': syncDuration.inMilliseconds,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Sync configuration settings
class SyncConfiguration {
  final SyncStrategy strategy;
  final Duration syncInterval;
  final Duration revocationCheckInterval;
  final bool enableBackgroundSync;
  final bool wifiOnlySync;
  final int maxConcurrentOperations;
  final int retryAttempts;
  final Duration retryDelay;

  const SyncConfiguration({
    this.strategy = SyncStrategy.balanced,
    this.syncInterval = const Duration(hours: 6),
    this.revocationCheckInterval = const Duration(hours: 1),
    this.enableBackgroundSync = true,
    this.wifiOnlySync = false,
    this.maxConcurrentOperations = 3,
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 30),
  });

  SyncConfiguration copyWith({
    SyncStrategy? strategy,
    Duration? syncInterval,
    Duration? revocationCheckInterval,
    bool? enableBackgroundSync,
    bool? wifiOnlySync,
    int? maxConcurrentOperations,
    int? retryAttempts,
    Duration? retryDelay,
  }) {
    return SyncConfiguration(
      strategy: strategy ?? this.strategy,
      syncInterval: syncInterval ?? this.syncInterval,
      revocationCheckInterval:
          revocationCheckInterval ?? this.revocationCheckInterval,
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
      wifiOnlySync: wifiOnlySync ?? this.wifiOnlySync,
      maxConcurrentOperations:
          maxConcurrentOperations ?? this.maxConcurrentOperations,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }
}

/// Credential sync status tracking
class CredentialSyncInfo {
  final String credentialId;
  final CredentialSyncStatus status;
  final DateTime lastSyncAttempt;
  final DateTime? lastSuccessfulSync;
  final int failureCount;
  final String? lastError;
  final Map<String, dynamic> metadata;

  const CredentialSyncInfo({
    required this.credentialId,
    required this.status,
    required this.lastSyncAttempt,
    this.lastSuccessfulSync,
    required this.failureCount,
    this.lastError,
    required this.metadata,
  });

  CredentialSyncInfo copyWith({
    CredentialSyncStatus? status,
    DateTime? lastSyncAttempt,
    DateTime? lastSuccessfulSync,
    int? failureCount,
    String? lastError,
    Map<String, dynamic>? metadata,
  }) {
    return CredentialSyncInfo(
      credentialId: credentialId,
      status: status ?? this.status,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
      failureCount: failureCount ?? this.failureCount,
      lastError: lastError ?? this.lastError,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Background credential synchronization service
class BackgroundSyncService {
  final SpruceKitServiceExtended _spruceKitService;
  final WalletManagerExtended _walletManager;
  final CredentialVerificationService _verificationService;

  // Service state
  bool _isInitialized = false;
  bool _isSyncActive = false;
  SyncConfiguration _configuration = const SyncConfiguration();

  // Sync tracking
  final Map<String, CredentialSyncInfo> _syncStatus = {};
  final List<SyncResult> _syncHistory = [];
  Timer? _syncTimer;
  Timer? _revocationTimer;

  // Network and device state
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;
  bool _isLowPowerMode = false;
  int _activeSyncOperations = 0;

  // Streams for real-time updates
  final StreamController<CredentialSyncInfo> _syncStatusController =
      StreamController<CredentialSyncInfo>.broadcast();
  final StreamController<SyncResult> _syncResultController =
      StreamController<SyncResult>.broadcast();

  BackgroundSyncService({
    required SpruceKitServiceExtended spruceKitService,
    required WalletManagerExtended walletManager,
    required CredentialVerificationService verificationService,
  }) : _spruceKitService = spruceKitService,
       _walletManager = walletManager,
       _verificationService = verificationService;

  /// Initialize background synchronization service
  Future<void> initialize({SyncConfiguration? configuration}) async {
    if (_isInitialized) return;

    try {
      Logger.info(
        'Initializing background sync service',
        name: 'BackgroundSyncService',
      );

      _configuration = configuration ?? _configuration;

      // Initialize network monitoring
      await _initializeNetworkMonitoring();

      // Initialize device state monitoring
      await _initializeDeviceStateMonitoring();

      // Load existing sync status
      await _loadSyncStatus();

      // Start sync timers if enabled
      if (_configuration.enableBackgroundSync) {
        _startSyncTimers();
      }

      _isInitialized = true;
      Logger.info(
        'Background sync service initialized successfully',
        name: 'BackgroundSyncService',
      );
    } catch (e) {
      Logger.error(
        'Failed to initialize background sync service',
        error: e,
        name: 'BackgroundSyncService',
      );
      throw Exception('Background sync initialization failed: $e');
    }
  }

  /// Update sync configuration
  Future<void> updateConfiguration(SyncConfiguration configuration) async {
    _configuration = configuration;

    // Restart timers with new configuration
    _stopSyncTimers();
    if (_configuration.enableBackgroundSync) {
      _startSyncTimers();
    }

    Logger.info(
      'Sync configuration updated: ${_configuration.strategy.name}',
      name: 'BackgroundSyncService',
    );
  }

  /// Perform manual synchronization
  Future<SyncResult> performSync({
    List<String>? credentialIds,
    SyncPriority priority = SyncPriority.medium,
    bool force = false,
  }) async {
    if (!_isInitialized) {
      throw Exception('Background sync service not initialized');
    }

    if (_isSyncActive && !force) {
      Logger.warning(
        'Sync already in progress, skipping',
        name: 'BackgroundSyncService',
      );
      return SyncResult(
        success: false,
        credentialsUpdated: 0,
        revocationsDetected: 0,
        errorsEncountered: 1,
        syncDuration: Duration.zero,
        errorMessage: 'Sync already in progress',
        timestamp: DateTime.now(),
      );
    }

    return await _executeSyncOperation(credentialIds, priority, force);
  }

  /// Check for credential revocations
  Future<List<String>> checkRevocations({List<String>? credentialIds}) async {
    if (!_isInitialized) {
      throw Exception('Background sync service not initialized');
    }

    try {
      Logger.info(
        'Checking credential revocations',
        name: 'BackgroundSyncService',
      );

      final credentials = credentialIds != null
          ? await _getCredentialsByIds(credentialIds)
          : await _walletManager.getAllCredentials();

      final revokedCredentials = <String>[];

      for (final credential in credentials) {
        try {
          final isRevoked = await _checkCredentialRevocation(credential);
          if (isRevoked) {
            revokedCredentials.add(credential['id'] as String);
            await _updateSyncStatus(
              credential['id'] as String,
              CredentialSyncStatus.revoked,
            );
          }
        } catch (e) {
          Logger.warning(
            'Failed to check revocation for credential ${credential['id']}',
            error: e,
            name: 'BackgroundSyncService',
          );
        }
      }

      Logger.info(
        'Revocation check completed: ${revokedCredentials.length} revoked',
        name: 'BackgroundSyncService',
      );

      return revokedCredentials;
    } catch (e) {
      Logger.error(
        'Revocation check failed',
        error: e,
        name: 'BackgroundSyncService',
      );
      rethrow;
    }
  }

  /// Get sync status for all credentials
  Map<String, CredentialSyncInfo> get syncStatus =>
      Map.unmodifiable(_syncStatus);

  /// Get sync status for specific credential
  CredentialSyncInfo? getSyncStatus(String credentialId) =>
      _syncStatus[credentialId];

  /// Get sync history
  List<SyncResult> get syncHistory => List.unmodifiable(_syncHistory);

  /// Stream of sync status updates
  Stream<CredentialSyncInfo> get syncStatusStream =>
      _syncStatusController.stream;

  /// Stream of sync results
  Stream<SyncResult> get syncResultStream => _syncResultController.stream;

  /// Check if sync is currently active
  bool get isSyncActive => _isSyncActive;

  /// Get current configuration
  SyncConfiguration get configuration => _configuration;

  /// Dispose of the service
  Future<void> dispose() async {
    Logger.info(
      'Disposing background sync service',
      name: 'BackgroundSyncService',
    );

    _stopSyncTimers();
    await _syncStatusController.close();
    await _syncResultController.close();

    _isInitialized = false;
  }

  // Private implementation methods

  Future<void> _initializeNetworkMonitoring() async {
    try {
      // Monitor connectivity changes
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        _lastConnectivity = result;
        _onConnectivityChanged(result);
      });

      // Get initial connectivity state
      _lastConnectivity = await Connectivity().checkConnectivity();
    } catch (e) {
      Logger.warning(
        'Failed to initialize network monitoring',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  Future<void> _initializeDeviceStateMonitoring() async {
    try {
      // Check for low power mode (iOS/Android specific)
      if (Platform.isIOS || Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();

        if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _isLowPowerMode = iosInfo.isPhysicalDevice; // Placeholder logic
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          _isLowPowerMode = false; // Android doesn't expose this easily
        }
      }
    } catch (e) {
      Logger.warning(
        'Failed to initialize device state monitoring',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      // Load existing sync status from storage (would use secure storage in real implementation)
      Logger.info(
        'Loading sync status from storage',
        name: 'BackgroundSyncService',
      );

      // Initialize sync status for all credentials
      final credentials = await _walletManager.getAllCredentials();
      for (final credential in credentials) {
        final credentialId = credential['id'] as String;
        if (!_syncStatus.containsKey(credentialId)) {
          _syncStatus[credentialId] = CredentialSyncInfo(
            credentialId: credentialId,
            status: CredentialSyncStatus.unknown,
            lastSyncAttempt: DateTime.now(),
            failureCount: 0,
            metadata: {},
          );
        }
      }
    } catch (e) {
      Logger.warning(
        'Failed to load sync status',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  void _startSyncTimers() {
    _stopSyncTimers();

    // Main sync timer
    _syncTimer = Timer.periodic(_configuration.syncInterval, (timer) {
      if (!_isSyncActive) {
        _performScheduledSync();
      }
    });

    // Revocation check timer
    _revocationTimer = Timer.periodic(_configuration.revocationCheckInterval, (
      timer,
    ) {
      _performRevocationCheck();
    });

    Logger.info('Sync timers started', name: 'BackgroundSyncService');
  }

  void _stopSyncTimers() {
    _syncTimer?.cancel();
    _revocationTimer?.cancel();
    _syncTimer = null;
    _revocationTimer = null;
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    Logger.info(
      'Connectivity changed: ${result.name}',
      name: 'BackgroundSyncService',
    );

    // Trigger sync if we gained connectivity and have pending updates
    if (result != ConnectivityResult.none &&
        _lastConnectivity == ConnectivityResult.none) {
      if (_hasPendingUpdates() && !_isSyncActive) {
        _performScheduledSync();
      }
    }
  }

  Future<void> _performScheduledSync() async {
    try {
      // Check if we should skip sync due to constraints
      if (!_shouldPerformSync()) {
        return;
      }

      Logger.info('Performing scheduled sync', name: 'BackgroundSyncService');
      await _executeSyncOperation(null, SyncPriority.low, false);
    } catch (e) {
      Logger.error(
        'Scheduled sync failed',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  Future<void> _performRevocationCheck() async {
    try {
      if (!_shouldPerformSync()) {
        return;
      }

      Logger.info(
        'Performing scheduled revocation check',
        name: 'BackgroundSyncService',
      );
      await checkRevocations();
    } catch (e) {
      Logger.error(
        'Scheduled revocation check failed',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  bool _shouldPerformSync() {
    // Check network constraints
    if (_configuration.wifiOnlySync &&
        _lastConnectivity != ConnectivityResult.wifi) {
      return false;
    }

    // Check if offline
    if (_lastConnectivity == ConnectivityResult.none) {
      return false;
    }

    // Check power constraints
    if (_isLowPowerMode &&
        _configuration.strategy == SyncStrategy.conservative) {
      return false;
    }

    // Check concurrent operations limit
    if (_activeSyncOperations >= _configuration.maxConcurrentOperations) {
      return false;
    }

    return true;
  }

  bool _hasPendingUpdates() {
    return _syncStatus.values.any(
      (status) =>
          status.status == CredentialSyncStatus.needsUpdate ||
          status.failureCount > 0,
    );
  }

  Future<SyncResult> _executeSyncOperation(
    List<String>? credentialIds,
    SyncPriority priority,
    bool force,
  ) async {
    final startTime = DateTime.now();
    int credentialsUpdated = 0;
    int revocationsDetected = 0;
    int errorsEncountered = 0;
    String? errorMessage;

    try {
      _isSyncActive = true;
      _activeSyncOperations++;

      Logger.info(
        'Starting sync operation (priority: ${priority.name})',
        name: 'BackgroundSyncService',
      );

      // Get credentials to sync
      final credentials = credentialIds != null
          ? await _getCredentialsByIds(credentialIds)
          : await _getCredentialsForSync(priority);

      // Process each credential
      for (final credential in credentials) {
        try {
          final credentialId = credential['id'] as String;

          // Update sync status to updating
          await _updateSyncStatus(credentialId, CredentialSyncStatus.updating);

          // Perform credential-specific sync
          final result = await _syncCredential(credential, priority);

          if (result['success'] as bool) {
            credentialsUpdated++;
            await _updateSyncStatus(
              credentialId,
              result['revoked'] == true
                  ? CredentialSyncStatus.revoked
                  : CredentialSyncStatus.upToDate,
            );

            if (result['revoked'] == true) {
              revocationsDetected++;
            }
          } else {
            errorsEncountered++;
            await _updateSyncStatus(
              credentialId,
              CredentialSyncStatus.needsUpdate,
              error: result['error'] as String?,
            );
          }
        } catch (e) {
          errorsEncountered++;
          Logger.warning(
            'Failed to sync credential ${credential['id']}',
            error: e,
            name: 'BackgroundSyncService',
          );
        }
      }

      final syncResult = SyncResult(
        success: errorsEncountered == 0,
        credentialsUpdated: credentialsUpdated,
        revocationsDetected: revocationsDetected,
        errorsEncountered: errorsEncountered,
        syncDuration: DateTime.now().difference(startTime),
        errorMessage: errorMessage,
        timestamp: DateTime.now(),
      );

      // Store sync result
      _syncHistory.add(syncResult);
      if (_syncHistory.length > 100) {
        _syncHistory.removeAt(0);
      }

      // Notify listeners
      _syncResultController.add(syncResult);

      Logger.info(
        'Sync operation completed: ${credentialsUpdated} updated, ${revocationsDetected} revoked, ${errorsEncountered} errors',
        name: 'BackgroundSyncService',
      );

      return syncResult;
    } catch (e) {
      errorMessage = e.toString();
      Logger.error(
        'Sync operation failed',
        error: e,
        name: 'BackgroundSyncService',
      );

      final syncResult = SyncResult(
        success: false,
        credentialsUpdated: credentialsUpdated,
        revocationsDetected: revocationsDetected,
        errorsEncountered: errorsEncountered + 1,
        syncDuration: DateTime.now().difference(startTime),
        errorMessage: errorMessage,
        timestamp: DateTime.now(),
      );

      _syncResultController.add(syncResult);
      return syncResult;
    } finally {
      _isSyncActive = false;
      _activeSyncOperations--;
    }
  }

  Future<List<Map<String, dynamic>>> _getCredentialsByIds(
    List<String> credentialIds,
  ) async {
    final allCredentials = await _walletManager.getAllCredentials();
    return allCredentials
        .where((cred) => credentialIds.contains(cred['id'] as String))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getCredentialsForSync(
    SyncPriority priority,
  ) async {
    final allCredentials = await _walletManager.getAllCredentials();

    // Filter credentials based on priority and sync status
    return allCredentials.where((credential) {
      final credentialId = credential['id'] as String;
      final syncInfo = _syncStatus[credentialId];

      if (syncInfo == null) return true;

      switch (priority) {
        case SyncPriority.critical:
          return syncInfo.status == CredentialSyncStatus.needsUpdate ||
              syncInfo.failureCount > 0;
        case SyncPriority.high:
          return syncInfo.status != CredentialSyncStatus.upToDate;
        case SyncPriority.medium:
          return syncInfo.lastSuccessfulSync == null ||
              DateTime.now().difference(syncInfo.lastSuccessfulSync!).inHours >
                  12;
        case SyncPriority.low:
          return syncInfo.lastSuccessfulSync == null ||
              DateTime.now().difference(syncInfo.lastSuccessfulSync!).inDays >
                  1;
      }
    }).toList();
  }

  Future<Map<String, dynamic>> _syncCredential(
    Map<String, dynamic> credential,
    SyncPriority priority,
  ) async {
    try {
      final credentialId = credential['id'] as String;

      // Check revocation status
      final isRevoked = await _checkCredentialRevocation(credential);
      if (isRevoked) {
        return {'success': true, 'revoked': true};
      }

      // Verify credential integrity
      final verificationResult = await _verificationService.verifyCredential(
        credential,
        options: {'skipRevocationCheck': true}, // Already checked above
      );

      if (!verificationResult.isValid) {
        return {
          'success': false,
          'error':
              'Credential verification failed: ${verificationResult.issues.join(', ')}',
        };
      }

      // Update metadata if needed
      await _updateCredentialMetadata(credential);

      return {'success': true, 'revoked': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> _checkCredentialRevocation(
    Map<String, dynamic> credential,
  ) async {
    try {
      // Use SpruceKit service to check revocation
      final revocationResult = await _spruceKitService.checkRevocationStatus(
        credential['id'] as String,
        credential,
      );

      return revocationResult['isRevoked'] as bool? ?? false;
    } catch (e) {
      Logger.warning(
        'Failed to check revocation for ${credential['id']}',
        error: e,
        name: 'BackgroundSyncService',
      );
      return false;
    }
  }

  Future<void> _updateCredentialMetadata(
    Map<String, dynamic> credential,
  ) async {
    try {
      // Update timestamp and other metadata
      credential['lastSyncTime'] = DateTime.now().toIso8601String();

      // Save updated credential
      await _walletManager.updateCredential(
        credential['id'] as String,
        credential,
      );
    } catch (e) {
      Logger.warning(
        'Failed to update metadata for ${credential['id']}',
        error: e,
        name: 'BackgroundSyncService',
      );
    }
  }

  Future<void> _updateSyncStatus(
    String credentialId,
    CredentialSyncStatus status, {
    String? error,
  }) async {
    final currentInfo = _syncStatus[credentialId];
    final now = DateTime.now();

    final updatedInfo = CredentialSyncInfo(
      credentialId: credentialId,
      status: status,
      lastSyncAttempt: now,
      lastSuccessfulSync: status == CredentialSyncStatus.upToDate
          ? now
          : currentInfo?.lastSuccessfulSync,
      failureCount: status == CredentialSyncStatus.upToDate
          ? 0
          : (currentInfo?.failureCount ?? 0) + (error != null ? 1 : 0),
      lastError: error,
      metadata: currentInfo?.metadata ?? {},
    );

    _syncStatus[credentialId] = updatedInfo;
    _syncStatusController.add(updatedInfo);

    Logger.debug(
      'Updated sync status for $credentialId: ${status.name}',
      name: 'BackgroundSyncService',
    );
  }
}
