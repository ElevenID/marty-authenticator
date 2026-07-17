/*
  privacyIDEA Authenticator

  Authors: Timo Sturm <timo.sturm@netknights.it>
           Frank Merkel <frank.merkel@netknights.it>

  Copyright (c) 2017-2025 NetKnights GmbH

  Licensed under the Apache License, Version 2.0 (the 'License');
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an 'AS IS' BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import 'dart:io';

import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gms_check/gms_check.dart';
import 'package:privacyidea_authenticator/firebase_options/default_firebase_options.dart';
import 'package:privacyidea_authenticator/utils/firebase_utils.dart';
import 'package:privacyidea_authenticator/utils/riverpod/riverpod_providers/generated_providers/localization_notifier.dart';

import '../../../../../../../model/riverpod_states/settings_state.dart';
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';
import '../model/enums/app_feature.dart';
import '../utils/customization/application_customization.dart';
import '../utils/globals.dart';
import '../utils/home_widget_utils.dart';
import '../utils/logger.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/app_constraints_notifier.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/settings_notifier.dart';
import '../views/add_token_manually_view/add_token_manually_view.dart';
import '../views/container_view/container_view.dart';
import '../views/feedback_view/feedback_view.dart';
import '../views/import_tokens_view/import_tokens_view.dart';
import '../views/license_view/license_view.dart';
import '../views/main_view/main_view.dart';
import '../views/push_token_view/push_tokens_view.dart';
import '../views/qr_scanner_view/qr_scanner_view.dart';
import '../views/settings_view/settings_view.dart';
import '../views/splash_screen/splash_screen.dart';
import '../views/spruce_demo_view/spruce_demo_view.dart';
import '../views/separated_spruce_demo_view/separated_spruce_demo_view.dart';
import '../views/main_view/document_view.dart';
import '../widgets/app_wrapper.dart';

void main() async {
  Logger.init(
    navigatorKey: globalNavigatorKey,
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Enable verbose logging if environment variable is set
      const verboseLogging = String.fromEnvironment(
        'VERBOSE_LOGGING',
        defaultValue: 'false',
      );
      if (verboseLogging.toLowerCase() == 'true') {
        Logger.setVerboseLogging(true);
        Logger.info('Verbose logging enabled via environment variable');
      }

      // Skip mobile-specific initialization on web and desktop platforms
      // Home widgets are only supported on iOS and Android
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await GmsCheck().checkGmsAvailability();
        await HomeWidgetUtils().registerInteractivityCallback(
          homeWidgetBackgroundCallback,
        );
        await HomeWidgetUtils().setAppGroupId(appGroupId);
      }

      // Firebase is only configured for mobile and web platforms
      if (kIsWeb || Platform.isIOS || Platform.isAndroid) {
        // Check if Firebase should be enabled and validate configuration
        DefaultFirebaseOptions.validateConfiguration();

        // Only proceed with Firebase initialization if it's enabled
        if (DefaultFirebaseOptions.isFirebaseEnabled) {
          Logger.info(
            '🔥 Firebase is enabled - initializing with configuration',
          );

          appFirebaseOptions = DefaultFirebaseOptions.currentPlatformOf(
            'netknights',
          );

          // Force Firebase initialization for testing FCM token retrieval
          if (const String.fromEnvironment(
                'VERBOSE_LOGGING',
                defaultValue: 'false',
              ).toLowerCase() ==
              'true') {
            try {
              await _initializeFirebaseForTesting();
            } catch (e) {
              Logger.warning('Failed to initialize Firebase for testing: $e');
            }
          }
        } else {
          Logger.info('🚫 Firebase is disabled - skipping initialization');
        }
      }
      runApp(
        EasyDynamicThemeWidget(
          initialThemeMode: ThemeMode.system,
          child: AppWrapper(
            child: PrivacyIDEAAuthenticator(
              ApplicationCustomization.defaultCustomization,
            ),
          ),
        ),
      );
    },
  );
}

class PrivacyIDEAAuthenticator extends ConsumerWidget {
  static ApplicationCustomization? currentCustomization;
  final ApplicationCustomization _customization;

  factory PrivacyIDEAAuthenticator(
    ApplicationCustomization customization, {
    Key? key,
  }) {
    PrivacyIDEAAuthenticator.currentCustomization = customization;
    return PrivacyIDEAAuthenticator._(customization: customization, key: key);
  }
  const PrivacyIDEAAuthenticator._({
    required ApplicationCustomization customization,
    super.key,
  }) : _customization = customization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    globalRef = ref;
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final localizations = AppLocalizations.of(context);
          if (localizations != null)
            ref
                .read(localizationNotifierProvider.notifier)
                .update(localizations);
          ref.read(appConstraintsNotifierProvider.notifier).update(constraints);
        });
        return MaterialApp(
          scrollBehavior: ScrollConfiguration.of(
            context,
          ).copyWith(physics: const ClampingScrollPhysics(), overscroll: false),
          debugShowCheckedModeBanner: true,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale:
              ref
                  .watch(settingsProvider)
                  .whenOrNull(data: (data) => data.currentLocale) ??
              SettingsState.localeDefault,
          title: _customization.appName,
          theme: _customization.generateLightTheme(),
          darkTheme: _customization.generateDarkTheme(),
          scaffoldMessengerKey: globalSnackbarKey,
          navigatorKey: globalNavigatorKey,
          themeMode: EasyDynamicTheme.of(context).themeMode,
          initialRoute: SplashScreen.routeName,
          routes: {
            AddTokenManuallyView.routeName: (context) =>
                const AddTokenManuallyView(),
            FeedbackView.routeName: (context) => const FeedbackView(),
            ImportTokensView.routeName: (context) => const ImportTokensView(),
            LicenseView.routeName: (context) => LicenseView(
              appImage:
                  _customization.licensesViewImage?.getWidget ??
                  _customization.splashScreenImage.getWidget,
              appName: _customization.appName,
              websiteLink: _customization.websiteLink,
            ),
            MainView.routeName: (context) => const DocumentView(),
            '/legacyMainView': (context) => MainView(
              appbarIcon: _customization.appbarIcon.getWidget,
              backgroundImage: _customization.backgroundImage?.getWidget,
              appName: _customization.appName,
              disablePatchNotes: _customization.disabledFeatures.contains(
                AppFeature.patchNotes,
              ),
            ),
            PushTokensView.routeName: (context) => const PushTokensView(),
            SettingsView.routeName: (context) => const SettingsView(),
            SplashScreen.routeName: (context) =>
                SplashScreen(customization: _customization),
            QRScannerView.routeName: (context) => const QRScannerView(),
            ContainerView.routeName: (context) => const ContainerView(),
            SpruceIdDemoView.routeName: (context) => const SpruceIdDemoView(),
            SeparatedSpruceIdDemoView.routeName: (context) =>
                const SeparatedSpruceIdDemoView(),
          },
        );
      },
    );
  }
}

/// Initialize Firebase for testing FCM token retrieval
Future<void> _initializeFirebaseForTesting() async {
  try {
    Logger.info('Initializing Firebase for testing FCM token retrieval...');

    // Create FirebaseUtils instance
    final firebaseUtils = FirebaseUtils();

    // Initialize Firebase app
    await firebaseUtils.initializeApp();
    Logger.info('Firebase app initialized for testing');

    // Get FCM token (this should trigger our logging)
    final fcmToken = await firebaseUtils.getFBToken();
    Logger.info('FCM Token for testing: $fcmToken');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to initialize Firebase for testing',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
