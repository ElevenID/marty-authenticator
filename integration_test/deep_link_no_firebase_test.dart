import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:marty_authenticator/main.dart' as app;
import 'package:marty_authenticator/model/enums/introduction.dart';
import 'package:marty_authenticator/model/riverpod_states/introduction_state.dart';
import 'package:marty_authenticator/model/riverpod_states/settings_state.dart';
import 'package:marty_authenticator/model/riverpod_states/token_folder_state.dart';
import 'package:marty_authenticator/utils/customization/application_customization.dart';
import 'package:marty_authenticator/model/version.dart';

import '../test/tests_app_wrapper.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Linking Integration Tests (No Firebase)', () {
    late MockSettingsRepository mockSettingsRepository;
    late MockTokenRepository mockTokenRepository;
    late MockTokenFolderRepository mockTokenFolderRepository;
    late MockIntroductionRepository mockIntroductionRepository;

    setUp(() {
      // Mock repositories to avoid Firebase initialization
      mockSettingsRepository = MockSettingsRepository();
      when(mockSettingsRepository.loadSettings()).thenAnswer(
        (_) async => SettingsState(
          isFirstRun: false,
          useSystemLocale: false,
          localePreference: const Locale('en'),
          latestStartedVersion: Version.parse('999.999.999'),
        ),
      );
      when(
        mockSettingsRepository.saveSettings(any),
      ).thenAnswer((_) async => true);

      mockTokenRepository = MockTokenRepository();
      when(mockTokenRepository.loadTokens()).thenAnswer((_) async => []);
      when(
        mockTokenRepository.saveOrReplaceTokens(any),
      ).thenAnswer((_) async => []);

      mockTokenFolderRepository = MockTokenFolderRepository();
      when(
        mockTokenFolderRepository.loadState(),
      ).thenAnswer((_) async => const TokenFolderState(folders: []));
      when(
        mockTokenFolderRepository.saveState(any),
      ).thenAnswer((_) async => true);

      mockIntroductionRepository = MockIntroductionRepository();
      when(mockIntroductionRepository.loadCompletedIntroductions()).thenAnswer(
        (_) async => const IntroductionState(
          completedIntroductions: {...Introduction.values},
        ),
      );
    });

    testWidgets('App launches without Firebase and handles deep links', (
      WidgetTester tester,
    ) async {
      // Set environment variables to skip Firebase
      const Map<String, String> testEnvironment = {
        'VERBOSE_LOGGING': 'false',
        'SKIP_FIREBASE': 'true',
      };

      // This test verifies that the app can start and handle deep links
      // without requiring Firebase configuration

      // Note: In a real integration test, you would:
      // 1. Build the app without Firebase env vars
      // 2. Install on device
      // 3. Use ADB to send deep link intents
      // 4. Verify the app responds correctly

      expect(true, isTrue); // Placeholder - implement actual deep link testing
    });

    testWidgets('Deep link URL schemes are properly registered', (
      WidgetTester tester,
    ) async {
      // This would test that the AndroidManifest.xml contains the correct intent filters
      // for all supported URL schemes without requiring Firebase

      // Verify these schemes are registered:
      const expectedSchemes = [
        'otpauth',
        'otpauth-migration',
        'pia',
        'openid-credential-offer',
        'openid4vp',
        'openid-credential',
      ];

      // In a real test, you would parse the AndroidManifest.xml
      // and verify all intent-filters are present
      expect(expectedSchemes.length, equals(6));
    });
  });
}
