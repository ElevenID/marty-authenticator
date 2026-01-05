/*
 * Marty Authenticator
 *
 * MartyChallengeOptionsWidget - UI widget for displaying challenge options
 *
 * Displays challenge options as buttons, adapting layout based on option count:
 * - 2-3 options: Horizontal row
 * - 4+ options: Vertical stack
 */

import 'package:flutter/material.dart';

import '../../models/marty_challenge.dart';
import '../../utils/customization/theme_extentions/push_request_theme.dart';
import '../button_widgets/cooldown_button.dart';

/// Widget that displays Marty challenge options as interactive buttons.
///
/// The layout adapts based on the number of options:
/// - 2-3 options: Displayed in a horizontal row
/// - 4+ options: Displayed in a vertical column
class MartyChallengeOptionsWidget extends StatelessWidget {
  /// The challenge options to display.
  final List<ChallengeOption> options;

  /// Callback when an option is selected.
  final Future<void> Function(ChallengeOption option) onOptionSelected;

  /// Height of each button.
  final double buttonHeight;

  /// Whether to show a loading indicator on the selected button.
  final bool showLoading;

  /// Currently selected option (if any, during loading).
  final String? selectedOptionId;

  const MartyChallengeOptionsWidget({
    super.key,
    required this.options,
    required this.onOptionSelected,
    this.buttonHeight = 48,
    this.showLoading = false,
    this.selectedOptionId,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use horizontal layout for 2-3 options, vertical for 4+
    if (options.length <= 3) {
      return _buildHorizontalLayout(context);
    } else {
      return _buildVerticalLayout(context);
    }
  }

  /// Build a horizontal row of buttons (for 2-3 options).
  Widget _buildHorizontalLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: options.map((option) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildOptionButton(context, option),
          ),
        );
      }).toList(),
    );
  }

  /// Build a vertical column of buttons (for 4+ options).
  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildOptionButton(context, option),
        );
      }).toList(),
    );
  }

  /// Build a single option button.
  Widget _buildOptionButton(BuildContext context, ChallengeOption option) {
    final isSelected = selectedOptionId == option.id;
    final isLoading = showLoading && isSelected;

    final pushRequestTheme =
        Theme.of(context).extensions[PushRequestTheme] as PushRequestTheme?;

    // Determine button color based on option ID
    final buttonColor = _getButtonColor(context, option, pushRequestTheme);

    return CooldownButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(buttonColor),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      onPressed: isLoading ? null : () => onOptionSelected(option),
      child: SizedBox(
        height: buttonHeight,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  option.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
        ),
      ),
    );
  }

  /// Get the button color based on option type.
  Color _getButtonColor(
    BuildContext context,
    ChallengeOption option,
    PushRequestTheme? theme,
  ) {
    // Use semantic colors for common actions
    final optionId = option.id.toLowerCase();

    if (optionId == 'accept' || optionId == 'approve' || optionId == 'yes') {
      return theme?.acceptColor ?? Colors.green;
    } else if (optionId == 'reject' || optionId == 'deny' || optionId == 'no') {
      return theme?.declineColor ?? Colors.red;
    }

    // Default: use primary color
    return Theme.of(context).colorScheme.primary;
  }
}

/// A simple dialog for displaying a Marty challenge with options.
class MartyChallengeDialog extends StatefulWidget {
  /// The challenge to display.
  final MartyChallenge challenge;

  /// Callback when an option is selected.
  final Future<bool> Function(MartyChallenge challenge, ChallengeOption option)
  onRespond;

  /// Callback when dialog is dismissed.
  final VoidCallback? onDismiss;

  const MartyChallengeDialog({
    super.key,
    required this.challenge,
    required this.onRespond,
    this.onDismiss,
  });

  @override
  State<MartyChallengeDialog> createState() => _MartyChallengeDialogState();
}

class _MartyChallengeDialogState extends State<MartyChallengeDialog> {
  bool _isLoading = false;
  String? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.challenge.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.challenge.question,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          MartyChallengeOptionsWidget(
            options: widget.challenge.options,
            onOptionSelected: _handleOptionSelected,
            showLoading: _isLoading,
            selectedOptionId: _selectedOptionId,
          ),
          if (widget.challenge.ttlSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ExpiryCountdown(
                expiresAt: widget.challenge.expiresAt,
                onExpired: () {
                  Navigator.of(context).pop();
                  widget.onDismiss?.call();
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleOptionSelected(ChallengeOption option) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _selectedOptionId = option.id;
    });

    try {
      final success = await widget.onRespond(widget.challenge, option);
      if (mounted) {
        Navigator.of(context).pop(success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedOptionId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond: ${e.toString()}')),
        );
      }
    }
  }
}

/// Countdown timer showing time until challenge expires.
class _ExpiryCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback? onExpired;

  const _ExpiryCountdown({required this.expiresAt, this.onExpired});

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final remaining = widget.expiresAt.difference(now);
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });

    if (remaining.isNegative || remaining == Duration.zero) {
      widget.onExpired?.call();
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateRemaining();
        if (_remaining > Duration.zero) {
          _startTimer();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    final isLow = _remaining.inSeconds < 30;

    return Text(
      'Expires in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: isLow ? Colors.red : null),
      textAlign: TextAlign.center,
    );
  }
}

/// Show a Marty challenge dialog.
///
/// Returns true if the challenge was responded to successfully.
Future<bool?> showMartyChallengeDialog({
  required BuildContext context,
  required MartyChallenge challenge,
  required Future<bool> Function(MartyChallenge, ChallengeOption) onRespond,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        MartyChallengeDialog(challenge: challenge, onRespond: onRespond),
  );
}
