import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/liveness_challenge.dart';
import '../../providers/verification_state_provider.dart';
import '../../widgets/common/back_button.dart';

class ReviewAndSubmitView extends ConsumerStatefulWidget {
  final LivenessChallenge? livenessChallenge;
  final Future<bool> Function()? authenticate;
  final Future<void> Function(LivenessChallenge challenge)? submitRequest;

  const ReviewAndSubmitView({
    super.key,
    this.livenessChallenge,
    this.authenticate,
    this.submitRequest,
  });

  @override
  ConsumerState<ReviewAndSubmitView> createState() =>
      _ReviewAndSubmitViewState();
}

class _ReviewAndSubmitViewState extends ConsumerState<ReviewAndSubmitView> {
  bool _isSubmitting = false;

  bool get _canSubmit {
    final challenge = widget.livenessChallenge;
    if (challenge == null ||
        widget.authenticate == null ||
        widget.submitRequest == null) {
      return false;
    }
    try {
      challenge.validateForCapture();
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final challenge = widget.livenessChallenge!;
      challenge.validateForCapture();
      if (!await widget.authenticate!()) {
        throw StateError('Authentication was not completed');
      }
      challenge.validateForCapture();
      await widget.submitRequest!(challenge);
      await ref
          .read(verificationStateProvider.notifier)
          .setStatus(VerificationStatus.pendingApproval);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted successfully!')),
      );
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
            Text(
              _canSubmit ? 'Ready to Submit' : 'Submission Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _canSubmit
                  ? 'Authenticate to securely submit your document and liveness check for verification.'
                  : 'Verified authentication and submission are not available for this request.',
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
                onPressed: _canSubmit ? _submit : null,
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
