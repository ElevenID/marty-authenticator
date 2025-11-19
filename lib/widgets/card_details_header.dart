import 'package:flutter/material.dart';
import 'package:privacyidea_authenticator/widgets/common/back_button.dart'
    as common;

class CardDetailsHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  const CardDetailsHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onShare,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: common.CustomBackButton(onPressed: onBack),
      leadingWidth: 80,
      title: null,
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed:
              onShare ??
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share functionality')),
                );
              },
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.white),
          onPressed:
              onMore ??
              () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('More options')));
              },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
