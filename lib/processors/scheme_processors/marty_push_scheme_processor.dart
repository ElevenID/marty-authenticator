/*
 * Marty Authenticator
 *
 * MartyPushSchemeProcessor - Handles marty:// deep links for push registration
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

import '../../model/processor_result.dart';
import '../../services/marty_push_service.dart';
import '../../utils/logger.dart';
import '../../utils/view_utils.dart';
import 'scheme_processor_interface.dart';

/// Result type for Marty push registration
class MartyPushRegistrationResult {
  final String deviceId;
  final String? registrationId;
  final String? organizationId;
  final String message;

  const MartyPushRegistrationResult({
    required this.deviceId,
    this.registrationId,
    this.organizationId,
    required this.message,
  });
}

/// Processor for marty:// deep links
///
/// Handles the following URI formats:
/// - marty://push-register?org={org_id}&api={api_url}&token={temp_token}&user={user_id}
class MartyPushSchemeProcessor extends SchemeProcessor {
  static const scheme = 'marty';
  static const hostPushRegister = 'push-register';

  // Query parameter keys
  static const String PARAM_ORG = 'org';
  static const String PARAM_API = 'api';
  static const String PARAM_TOKEN = 'token';
  static const String PARAM_USER = 'user';

  // Localization strings (will use ARB keys after flutter gen-l10n)
  // For now, use inline strings that match the ARB entries
  static const String _msgSuccess = 'Device registered for push notifications';
  static const String _msgFailed = 'Push notification registration failed';
  static const String _msgExpired = 'Registration link has expired';
  static const String _msgMissingToken =
      'Invalid registration link: missing token';
  static const String _msgMissingUser =
      'Invalid registration link: missing user ID';

  @override
  Set<String> get supportedSchemes => {scheme};

  const MartyPushSchemeProcessor();

  @override
  Future<List<ProcessorResult<MartyPushRegistrationResult>>?> processUri(
    Uri uri, {
    bool fromInit = false,
  }) async {
    if (!supportedSchemes.contains(uri.scheme)) return null;

    Logger.info(
      'MartyPushSchemeProcessor: Processing URI with host=${uri.host}',
    );

    switch (uri.host) {
      case hostPushRegister:
        return _processPushRegister(uri);
      default:
        Logger.warning('MartyPushSchemeProcessor: Unknown host: ${uri.host}');
        return null;
    }
  }

  /// Process push-register deep link
  ///
  /// URI format: marty://push-register?org={org_id}&api={api_url}&token={temp_token}&user={user_id}
  Future<List<ProcessorResult<MartyPushRegistrationResult>>>
  _processPushRegister(Uri uri) async {
    Logger.info('MartyPushSchemeProcessor: Processing push-register deep link');

    final organizationId = uri.queryParameters[PARAM_ORG];
    final apiUrl = uri.queryParameters[PARAM_API];
    final registrationToken = uri.queryParameters[PARAM_TOKEN];
    final userId = uri.queryParameters[PARAM_USER];

    // Validate required parameters
    if (registrationToken == null || registrationToken.isEmpty) {
      Logger.warning('MartyPushSchemeProcessor: Missing registration token');
      showErrorStatusMessage(message: (_) => _msgMissingToken);
      return [ProcessorResult.failed((_) => _msgMissingToken)];
    }

    if (userId == null || userId.isEmpty) {
      Logger.warning('MartyPushSchemeProcessor: Missing user ID');
      showErrorStatusMessage(message: (_) => _msgMissingUser);
      return [ProcessorResult.failed((_) => _msgMissingUser)];
    }

    try {
      // Get the MartyPushService instance
      final pushService = MartyPushService.instance;

      // Build QR data map for registration
      final qrData = <String, dynamic>{
        'organization_id': organizationId,
        'api_url': apiUrl,
        'registration_token': registrationToken,
        'user_id': userId,
      };

      Logger.info('MartyPushSchemeProcessor: Calling registerFromQRCode');

      // Perform registration
      final result = await pushService.registerFromQRCode(qrData);

      if (result['success'] == true) {
        Logger.info('MartyPushSchemeProcessor: Registration successful');

        // Show success banner
        showSuccessStatusMessage(message: (_) => _msgSuccess);

        return [
          ProcessorResult.success(
            MartyPushRegistrationResult(
              deviceId: result['device_id'] as String,
              registrationId: result['registration_id'] as String?,
              organizationId: result['organization_id'] as String?,
              message: result['message'] as String? ?? _msgSuccess,
            ),
          ),
        ];
      } else {
        Logger.warning(
          'MartyPushSchemeProcessor: Registration returned failure',
        );

        final errorMsg = result['message'] as String? ?? _msgFailed;

        // Show error banner
        showErrorStatusMessage(
          message: (_) => _msgFailed,
          details: (_) => errorMsg,
        );

        return [
          ProcessorResult.failed((_) => _msgFailed, error: result['message']),
        ];
      }
    } on Exception catch (e) {
      Logger.error('MartyPushSchemeProcessor: Registration failed', error: e);

      // Determine if it's an expired token error
      final isExpired =
          e.toString().contains('expired') ||
          e.toString().contains('invalid token');

      final errorMessage = isExpired ? _msgExpired : _msgFailed;

      // Show appropriate error banner
      showErrorStatusMessage(
        message: (_) => errorMessage,
        details: (_) => e.toString(),
      );

      return [ProcessorResult.failed((_) => errorMessage, error: e)];
    }
  }
}
