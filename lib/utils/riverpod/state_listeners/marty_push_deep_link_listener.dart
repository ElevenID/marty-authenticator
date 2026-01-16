/*
 * Marty Authenticator
 *
 * MartyPushDeepLinkListener - Handles marty:// deep links for push registration
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../interfaces/riverpod/state_listeners/state_notifier_provider_listeners/deep_link_listener.dart';
import '../../../model/deeplink.dart';
import '../../../processors/scheme_processors/marty_push_scheme_processor.dart';
import '../../../utils/logger.dart';

/// Listener for marty:// deep links to handle push notification registration
///
/// This listener watches the deep link provider and processes any incoming
/// marty:// URIs through the MartyPushSchemeProcessor.
class MartyPushDeepLinkListener extends DeepLinkListener {
  const MartyPushDeepLinkListener({required super.provider})
    : super(
        onNewState: _onNewState,
        listenerName: 'MartyPushDeepLinkListener().processUri',
      );

  static void _onNewState(
    WidgetRef ref,
    AsyncValue<DeepLink>? previous,
    AsyncValue<DeepLink> next,
  ) {
    next.whenData((deepLink) async {
      final uri = deepLink.uri;

      // Only process marty:// scheme URIs
      if (uri.scheme != MartyPushSchemeProcessor.scheme) {
        return;
      }

      Logger.info(
        'MartyPushDeepLinkListener: Processing marty:// deep link: $uri',
      );

      try {
        const processor = MartyPushSchemeProcessor();
        final results = await processor.processUri(uri);

        if (results == null || results.isEmpty) {
          Logger.warning(
            'MartyPushDeepLinkListener: No results from processor',
          );
          return;
        }

        // Results are already handled by the processor (success/error banners shown)
        // Just log the outcome
        for (final result in results) {
          if (result.isSuccess) {
            final data = result.asSuccess?.resultData;
            Logger.info(
              'MartyPushDeepLinkListener: Registration successful for device: ${data?.deviceId}',
            );
          } else {
            Logger.warning('MartyPushDeepLinkListener: Registration failed');
          }
        }
      } catch (e) {
        Logger.error(
          'MartyPushDeepLinkListener: Error processing deep link',
          error: e,
        );
      }
    });
  }
}
