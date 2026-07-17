import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:marty_authenticator/interfaces/repo/introduction_repository.dart';
import 'package:marty_authenticator/interfaces/repo/settings_repository.dart';
import 'package:marty_authenticator/interfaces/repo/token_repository.dart';
import 'package:marty_authenticator/repo/secure_storage.dart';
import 'package:marty_authenticator/utils/allow_screenshot_utils.dart';
import 'package:marty_authenticator/utils/ecc_utils.dart';
import 'package:marty_authenticator/utils/rsa_utils.dart';

@GenerateNiceMocks([
  MockSpec<TokenRepository>(),
  MockSpec<SettingsRepository>(),
  MockSpec<IntroductionRepository>(),
  MockSpec<RsaUtils>(),
  MockSpec<EccUtils>(),
  MockSpec<AllowScreenshotUtils>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<SecureStorage>(),
])
class TestsAppWrapper extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;

  const TestsAppWrapper({
    super.key,
    required this.child,
    this.overrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: EasyDynamicThemeWidget(child: child),
    );
  }
}

Future<void> pumpUntilFindNWidgets(
  WidgetTester tester,
  Finder finder,
  int n,
  Duration timeOut,
) async {
  final startTime = DateTime.now();
  while (true) {
    await tester.pump();
    if (DateTime.now().difference(startTime) > timeOut) {
      break;
    }
    if (tester.widgetList(finder).length == n) {
      break;
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
