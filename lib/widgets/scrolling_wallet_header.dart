import 'package:flutter/material.dart';
import '../widgets/dialogs/add_to_wallet_dialog.dart';

class ScrollingWalletHeader extends StatelessWidget {
  final double opacity;

  const ScrollingWalletHeader({super.key, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      toolbarHeight: 60.0,
      floating: true,
      pinned: false,
      snap: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withOpacity(opacity),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      title: Opacity(
        opacity: opacity,
        child: Text(
          'Wallet',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      actions: [
        _buildActionButton(
          icon: Icons.qr_code_scanner,
          onPressed: () => _showQRScanner(context),
        ),
        _buildActionButton(
          icon: Icons.add,
          onPressed: () => AddToWalletDialog.show(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 24,
          color: Colors.black,
          padding: const EdgeInsets.all(8.0),
        ),
      ),
    );
  }

  void _showQRScanner(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR Scanner opened')));
  }
}
