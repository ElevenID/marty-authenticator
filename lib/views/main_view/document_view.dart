import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:marty_authenticator/l10n/app_localizations.dart';

import '../../models/card_data.dart';
import '../../providers/card_state_provider.dart';
import '../../controllers/scroll_fade_controller.dart';
import '../../widgets/scrolling_wallet_header.dart';
import '../../widgets/cascading_card_list.dart';
import '../../widgets/stacked_notification_cards.dart';
import '../../widgets/dialog_widgets/default_dialog.dart';
import '../../utils/view_utils.dart';
import '../../utils/riverpod/providers/credentials_provider.dart';
import '../qr_scanner_view/qr_scanner_view.dart';
import '../card_details_screen.dart';
import '../grouped_card_details_screen.dart';
import '../expired_passes_view.dart';
import 'main_view_widgets/card_widgets/passport_placeholder_card.dart';
import 'main_view_widgets/card_widgets/mdl_placeholder_card.dart';

class DocumentView extends ConsumerStatefulWidget {
  const DocumentView({super.key});

  @override
  ConsumerState<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends ConsumerState<DocumentView> {
  late ScrollFadeController fadeController;

  @override
  void initState() {
    super.initState();
    fadeController = ScrollFadeController(
      fadeDistance: 100.0,
      onOpacityChanged: () => setState(() {}),
    );
    fadeController.initialize();
  }

  @override
  void dispose() {
    fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardGroups = ref.watch(activeCardGroupsProvider);
    final expiredCards = ref.watch(expiredCardsProvider);
    final draggingCard = ref.watch(draggingCardProvider);
    final isDragging = draggingCard != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          NestedScrollView(
            controller: fadeController.scrollController,
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    ScrollingWalletHeader(
                      opacity: fadeController.headerOpacity,
                      onScanPressed: _handleScanPressed,
                    ),
                  ];
                },
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StackedNotificationCards(
                    notifications: [
                      NotificationCardData(
                        title: 'Apple Pay',
                        subtitle:
                            'Add a card to start paying with your iPhone this holiday.',
                        icon: const Icon(Icons.payment, color: Colors.black),
                        color: Colors.white,
                      ),
                      NotificationCardData(
                        title: 'Apple Cash',
                        subtitle: 'Set up Apple Cash',
                        icon: const Icon(
                          Icons.attach_money,
                          color: Colors.black,
                        ),
                        color: Colors.white,
                      ),
                      NotificationCardData(
                        title: 'MetLife',
                        subtitle: 'Employee Name',
                        icon: const Icon(
                          Icons.health_and_safety,
                          color: Colors.blue,
                        ),
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const PassportPlaceholderCard(),
                  const MdlPlaceholderCard(),
                  CascadingCardList(
                    cardGroups: cardGroups,
                    isDragging: isDragging,
                    onCardTap: _handleCardTap,
                    onCardLongPress: _handleCardLongPress,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(cardStateProvider.notifier)
                          .reorderGroup(oldIndex, newIndex);
                    },
                  ),
                  const SizedBox(height: 40),
                  if (expiredCards.isNotEmpty)
                    IgnorePointer(
                      ignoring: fadeController.footerOpacity < 0.1,
                      child: Opacity(
                        opacity: fadeController.footerOpacity,
                        child: _buildExpiredPassesButton(expiredCards.length),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScanPressed() async {
    try {
      if (await Permission.camera.isPermanentlyDenied) {
        showAsyncDialog(
          builder: (_) => DefaultDialog(
            title: Text(
              AppLocalizations.of(context)!.grantCameraPermissionDialogTitle,
            ),
            content: Text(
              AppLocalizations.of(
                context,
              )!.grantCameraPermissionDialogPermanentlyDenied,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      // Handle platform-specific permission issues
    }
    if (!mounted) return;

    final qrCode = await Navigator.pushNamed(context, QRScannerView.routeName);
    if (qrCode == null || !mounted) return;
    final handled = await ref
        .read(credentialsProvider.notifier)
        .handleCredentialOffer(qrCode.toString());
    if (!handled) {
      showErrorStatusMessage(message: (l) => l.invalidQrScan);
    }
  }

  Widget _buildExpiredPassesButton(int count) {
    // Use the inverse of header opacity for the bottom button
    // As header fades out (scroll down), this button fades in?
    // Or maybe it should just be visible at the bottom.
    // The user said "animation that makes a button at the bottom appear".
    // And "animation should be the same one used on the top header".
    // The top header fades based on scroll offset 0 to 100.
    // If we want it to appear when we scroll to the end, we might need to check scroll position relative to max scroll.
    // But for now, let's just place it at the bottom.

    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExpiredPassesView()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            'View $count Expired Pass${count > 1 ? 'es' : ''}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardTap(CardData cardData) {
    // Find the card group that contains this card
    final cardGroups = ref.read(activeCardGroupsProvider);
    CardGroup? targetGroup;

    for (final group in cardGroups) {
      if (group.cards.any((card) => card.title == cardData.title)) {
        targetGroup = group;
        break;
      }
    }

    if (targetGroup != null) {
      // Find the index of the tapped card in the group
      final cardIndex = targetGroup.cards.indexWhere(
        (card) => card.title == cardData.title,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupedCardDetailsScreen(
            cardGroup: targetGroup!,
            initialIndex: cardIndex >= 0 ? cardIndex : 0,
          ),
        ),
      );
    } else {
      // Fallback to original card details screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CardDetailsScreen(cardData: cardData.toMap()),
        ),
      );
    }
  }

  void _handleCardLongPress(CardData cardData) {
    // Dragging is now handled by LongPressDraggable in WalletCard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reordering ${cardData.title}'),
        backgroundColor: cardData.color,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
