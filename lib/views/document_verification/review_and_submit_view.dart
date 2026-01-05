import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/liveness_challenge.dart';
import '../../providers/verification_state_provider.dart';
import '../../widgets/common/back_button.dart';
// import '../../utils/lock_auth.dart';
// import 'package:privacyidea_authenticator/l10n/app_localizations.dart';

class ReviewAndSubmitView extends ConsumerStatefulWidget {
  final LivenessChallenge? livenessChallenge;

  const ReviewAndSubmitView({super.key, this.livenessChallenge});

  @override
  ConsumerState<ReviewAndSubmitView> createState() =>
      _ReviewAndSubmitViewState();
}

class _ReviewAndSubmitViewState extends ConsumerState<ReviewAndSubmitView> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      // For web testing, skip localization check
      // final localization = AppLocalizations.of(context);
      // if (localization == null) return;

      // For web testing, always authenticate successfully
      final bool didAuthenticate = true; // await lockAuth(
      //   reason: (l10n) => 'Please authenticate to submit your ID verification',
      //   localization: localization,
      // );

      if (didAuthenticate) {
        // Simulate network request
        await Future.delayed(const Duration(seconds: 2));

        // Update state
        await ref
            .read(verificationStateProvider.notifier)
            .setStatus(VerificationStatus.pendingApproval);

        if (!mounted) return;

        // Pop back to root or show success
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification submitted successfully!')),
        );
      }
    } catch (e) {
      Logger.error(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leadingWidth: 100,
        leading: const CustomBackButton(),
        title: const Text(
          'Review & Submit',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ready to Submit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Your document and liveness check have been captured. Please authenticate to securely submit your information for verification.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (widget.livenessChallenge != null) ...[
              const SizedBox(height: 16),
              Text(
                'Liveness Challenge: ${widget.livenessChallenge!.challengeId}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              Text(
                'Nonce: ${widget.livenessChallenge!.nonce}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              Text(
                'Expires: ${widget.livenessChallenge!.expiresAt.toIso8601String()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Authenticate & Submit',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
