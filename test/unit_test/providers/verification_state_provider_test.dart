import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/verification_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists verification state', () async {
    SharedPreferences.setMockInitialValues({
      'verification_status': VerificationStatus.issued.toString(),
    });
    final notifier = VerificationStateNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, VerificationStatus.issued);

    await notifier.setStatus(VerificationStatus.pendingApproval);
    expect(notifier.state, VerificationStatus.pendingApproval);
    expect(
      (await SharedPreferences.getInstance()).getString('verification_status'),
      VerificationStatus.pendingApproval.toString(),
    );
  });

  test('invalid or absent persisted state defaults to none', () async {
    SharedPreferences.setMockInitialValues({'verification_status': 'invalid'});
    final invalid = VerificationStateNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(invalid.state, VerificationStatus.none);

    SharedPreferences.setMockInitialValues({});
    final absent = VerificationStateNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(absent.state, VerificationStatus.none);
  });
}
