/*
  privacyIDEA Authenticator - Demo Base Configuration

  Authors: Adam Burdett <adam.burdett@netknights.it>

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

/// Base configuration for demo main entry points
/// Provides common setup for all demo flavors

import 'dart:io';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gms_check/gms_check.dart';
import 'package:privacyidea_authenticator/firebase_options/default_firebase_options.dart';
import 'package:privacyidea_authenticator/utils/logger.dart';

import '../l10n/app_localizations.dart';
import '../model/enums/app_feature.dart';
import '../utils/customization/application_customization.dart';
import '../utils/globals.dart';
import '../utils/home_widget_utils.dart';
import '../model/riverpod_states/settings_state.dart';
import '../utils/riverpod/providers/spruce_providers.dart';
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
import '../mocks/mock_spruce_services.dart';
import '../mocks/mock_qr_scanner_service.dart';

/// Function type for loading demo credentials
typedef CredentialsLoader =
    Future<List<String>> Function(MockSpruceIdServices mockServices);

/// Run the demo app with specified credentials
Future<void> runDemoApp({
  required String demoName,
  required CredentialsLoader credentialsLoader,
}) async {
  Logger.init(
    navigatorKey: globalNavigatorKey,
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      Logger.warning('🎭 DEMO MODE: $demoName 🎭');

      // Skip mobile-specific initialization on web and desktop platforms
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await GmsCheck().checkGmsAvailability();
        await HomeWidgetUtils().registerInteractivityCallback(
          homeWidgetBackgroundCallback,
        );
        await HomeWidgetUtils().setAppGroupId(appGroupId);
      }

      // Firebase configuration
      if (kIsWeb || Platform.isIOS || Platform.isAndroid) {
        DefaultFirebaseOptions.validateConfiguration();

        if (DefaultFirebaseOptions.isFirebaseEnabled) {
          Logger.info('🔥 Firebase is enabled');
          appFirebaseOptions = DefaultFirebaseOptions.currentPlatformOf(
            'netknights',
          );
        } else {
          Logger.info('🚫 Firebase is disabled');
        }
      }

      // Create mock SpruceID services
      final mockServices = MockSpruceIdServices.createDefault(
        config: MockSpruceIdConfig.realistic(),
      );

      // Load demo-specific credentials
      final loadedCredentials = await credentialsLoader(mockServices);
      for (final credName in loadedCredentials) {
        Logger.info('✅ Loaded: $credName');
      }

      // Setup mock QR scanner
      final mockQrConfig = MockQrScannerConfig.withAllFixtures();
      setMockQrScannerConfig(mockQrConfig);
      Logger.info('✅ Configured mock QR scanner');

      runApp(
        EasyDynamicThemeWidget(
          initialThemeMode: ThemeMode.system,
          child: AppWrapper(
            overrides: [
              // Override SpruceID providers with mock implementations
              spruceIdPlatformServiceProvider.overrideWithValue(
                mockServices.platformService,
              ),
              spruceIdClientProvider.overrideWithValue(mockServices.client),
              spruceIdWalletManagerProvider.overrideWithValue(
                mockServices.walletManager,
              ),
              spruceIdMdocManagerProvider.overrideWithValue(
                mockServices.mdocManager,
              ),
              spruceIdSdJwtManagerProvider.overrideWithValue(
                mockServices.sdJwtManager,
              ),
            ],
            child: PrivacyIDEAAuthenticatorDemo(
              customization: ApplicationCustomization.defaultCustomization,
              demoName: demoName,
            ),
          ),
        ),
      );
    },
  );
}

class PrivacyIDEAAuthenticatorDemo extends ConsumerWidget {
  final String demoName;
  final ApplicationCustomization _customization;

  const PrivacyIDEAAuthenticatorDemo({
    required this.demoName,
    required ApplicationCustomization customization,
    super.key,
  }) : _customization = customization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '${_customization.appName} - $demoName',
      navigatorKey: globalNavigatorKey,
      navigatorObservers: [
        if (getMockQrScannerConfig() != null) MockQrScannerNavigatorObserver(),
      ],
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale:
          ref
              .watch(settingsProvider)
              .whenOrNull(data: (data) => data.currentLocale) ??
          SettingsState.localeDefault,
      theme: _customization.generateLightTheme(),
      darkTheme: _customization.generateDarkTheme(),
      scaffoldMessengerKey: globalSnackbarKey,
      themeMode: EasyDynamicTheme.of(context).themeMode,
      initialRoute: SplashScreen.routeName,
      routes: {
        AddTokenManuallyView.routeName: (context) =>
            const AddTokenManuallyView(),
        FeedbackView.routeName: (context) => const FeedbackView(),
        MainView.routeName: (context) => const DocumentView(),
        ImportTokensView.routeName: (context) => const ImportTokensView(),
        LicenseView.routeName: (context) => LicenseView(
          appImage:
              _customization.licensesViewImage?.getWidget ??
              _customization.splashScreenImage.getWidget,
          appName: _customization.appName,
          websiteLink: _customization.websiteLink,
        ),
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
  }
}
