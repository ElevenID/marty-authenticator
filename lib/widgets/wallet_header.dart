import 'package:flutter/material.dart';
import 'package:privacyidea_authenticator/widgets/dialogs/add_to_wallet_dialog.dart';

class WalletHeader extends StatelessWidget implements PreferredSizeWidget {
  const WalletHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Documents'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Scanner opened')),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
            iconSize: 24,
            color: Colors.black,
            padding: const EdgeInsets.all(8.0),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () {
              AddToWalletDialog.show(context);
            },
            icon: const Icon(Icons.add),
            iconSize: 24,
            color: Colors.black,
            padding: const EdgeInsets.all(8.0),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: PopupMenuButton<String>(
            onSelected: (value) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$value selected')));
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'Orders',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Orders', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Preauthorized Payments',
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Preauthorized Payments',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Settings', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            iconSize: 24,
            padding: const EdgeInsets.all(8.0),
            popUpAnimationStyle: AnimationStyle(
              duration: const Duration(milliseconds: 200),
            ),
            menuPadding: EdgeInsets.zero,
            color: const Color(0xFF424242),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
