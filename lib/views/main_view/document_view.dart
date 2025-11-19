import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_data.dart';
import '../../providers/card_data_provider.dart';
import '../../controllers/scroll_fade_controller.dart';
import '../../widgets/scrolling_wallet_header.dart';
import '../../widgets/cascading_card_list.dart';
import '../card_details_screen.dart';

class DocumentView extends ConsumerStatefulWidget {
  const DocumentView({super.key});

  @override
  ConsumerState<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends ConsumerState<DocumentView> {
  late List<CardGroup> cardGroups;
  bool isDragging = false;
  late ScrollFadeController fadeController;

  @override
  void initState() {
    super.initState();
    cardGroups = CardDataProvider.getCardGroups();
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        controller: fadeController.scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            ScrollingWalletHeader(opacity: fadeController.headerOpacity),
          ];
        },
        body: CascadingCardList(
          cardGroups: cardGroups,
          isDragging: isDragging,
          onCardTap: _handleCardTap,
          onCardLongPress: _handleCardLongPress,
        ),
      ),
    );
  }

  void _handleCardTap(CardData cardData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardDetailsScreen(cardData: cardData.toMap()),
      ),
    );
  }

  void _handleCardLongPress(CardData cardData) {
    setState(() {
      isDragging = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Drag mode enabled for ${cardData.title}'),
        backgroundColor: cardData.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}