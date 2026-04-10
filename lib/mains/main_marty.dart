/*
  Marty Authenticator

  A Digital Document Wallet and Authenticator App.

  Copyright (c) 2025 Marty Identity Platform
  Licensed under the Apache License, Version 2.0
*/

import 'dart:io';

import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marty_authenticator/l10n/app_localizations.dart';
import 'package:marty_authenticator/utils/logger.dart';
import 'package:marty_authenticator/utils/globals.dart';
import 'package:marty_authenticator/utils/customization/application_customization.dart';
import 'package:marty_authenticator/utils/riverpod/riverpod_providers/generated_providers/app_constraints_notifier.dart';
import 'package:marty_authenticator/utils/riverpod/riverpod_providers/generated_providers/localization_notifier.dart';
import 'package:marty_authenticator/utils/riverpod/riverpod_providers/generated_providers/settings_notifier.dart';
import 'package:marty_authenticator/model/riverpod_states/settings_state.dart';
import 'package:marty_authenticator/views/feedback_view/feedback_view.dart';
import 'package:marty_authenticator/views/license_view/license_view.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';
import 'package:marty_authenticator/views/main_view/main_view.dart';
import 'package:marty_authenticator/views/qr_scanner_view/qr_scanner_view.dart';
import 'package:marty_authenticator/views/settings_view/settings_view.dart';
import 'package:marty_authenticator/views/splash_screen/splash_screen.dart';
import 'package:marty_authenticator/widgets/app_wrapper.dart';

void main() async {
  Logger.init(
    navigatorKey: globalNavigatorKey,
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Enable verbose logging via environment variable
      const verboseLogging = String.fromEnvironment(
        'VERBOSE_LOGGING',
        defaultValue: 'false',
      );
      if (verboseLogging.toLowerCase() == 'true') {
        Logger.setVerboseLogging(true);
        Logger.info('Verbose logging enabled via environment variable');
      }

      Logger.info('Starting Marty Authenticator');

      final customization = ApplicationCustomization.defaultCustomization;

      runApp(
        EasyDynamicThemeWidget(
          initialThemeMode: ThemeMode.system,
          child: AppWrapper(child: MartyAuthenticator(customization)),
        ),
      );
    },
  );
}

class MartyAuthenticator extends ConsumerWidget {
  static ApplicationCustomization? currentCustomization;
  final ApplicationCustomization _customization;

  factory MartyAuthenticator(
    ApplicationCustomization customization, {
    Key? key,
  }) {
    MartyAuthenticator.currentCustomization = customization;
    return MartyAuthenticator._(customization: customization, key: key);
  }

  const MartyAuthenticator._({
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
          if (localizations != null) {
            ref
                .read(localizationNotifierProvider.notifier)
                .update(localizations);
          }
          ref.read(appConstraintsNotifierProvider.notifier).update(constraints);
        });

        return MaterialApp(
          scrollBehavior: ScrollConfiguration.of(
            context,
          ).copyWith(physics: const ClampingScrollPhysics(), overscroll: false),
          debugShowCheckedModeBanner: false,
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
            FeedbackView.routeName: (context) => const FeedbackView(),
            LicenseView.routeName: (context) => LicenseView(
              appImage:
                  _customization.licensesViewImage?.getWidget ??
                  _customization.splashScreenImage.getWidget,
              appName: _customization.appName,
              websiteLink: _customization.websiteLink,
            ),
            MainView.routeName: (context) => const DocumentView(),
            SettingsView.routeName: (context) => const SettingsView(),
            SplashScreen.routeName: (context) =>
                SplashScreen(customization: _customization),
            QRScannerView.routeName: (context) => const QRScannerView(),
          },
        );
      },
    );
  }
}
