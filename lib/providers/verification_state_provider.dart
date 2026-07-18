import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VerificationStatus { none, pendingApproval, issued }

class VerificationStateNotifier extends StateNotifier<VerificationStatus> {
  VerificationStateNotifier() : super(VerificationStatus.none) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final statusString = prefs.getString('verification_status');
    if (statusString != null) {
      state = VerificationStatus.values.firstWhere(
        (e) => e.toString() == statusString,
        orElse: () => VerificationStatus.none,
      );
    }
  }

  Future<void> setStatus(VerificationStatus status) async {
    state = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verification_status', status.toString());
  }
}

final verificationStateProvider =
    StateNotifierProvider<VerificationStateNotifier, VerificationStatus>((ref) {
      return VerificationStateNotifier();
    });
