import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_data.dart';
import '../../providers/card_state_provider.dart';
import 'expired_pass_details_view.dart';

class ExpiredPassesView extends ConsumerStatefulWidget {
  const ExpiredPassesView({super.key});

  @override
  ConsumerState<ExpiredPassesView> createState() => _ExpiredPassesViewState();
}

class _ExpiredPassesViewState extends ConsumerState<ExpiredPassesView> {
  bool isEditMode = false;
  Set<String> selectedCards = {};

  @override
  Widget build(BuildContext context) {
    final expiredCards = ref.watch(expiredCardsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: isEditMode
            ? TextButton(
                onPressed: _toggleSelectAll,
                child: Text(
                  selectedCards.length == expiredCards.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(color: Colors.blue, fontSize: 16),
                ),
              )
            : const BackButton(color: Colors.blue),
        leadingWidth: 100,
        title: Text(
          isEditMode ? 'Edit' : 'Expired',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                isEditMode = !isEditMode;
                selectedCards.clear();
              });
            },
            child: Text(
              isEditMode ? 'Cancel' : 'Edit',
              style: const TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: expiredCards.length,
              itemBuilder: (context, index) {
                final card = expiredCards[index];
                return _buildExpiredCardItem(card);
              },
            ),
          ),
          if (isEditMode && selectedCards.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _deleteSelected,
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                  Text(
                    '${selectedCards.length} Pass${selectedCards.length > 1 ? 'es' : ''} Selected',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: _unhideSelected,
                    child: const Text(
                      'Unhide',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpiredCardItem(CardData card) {
    final isSelected = selectedCards.contains(card.title);

    return ListTile(
      leading: isEditMode
          ? IconButton(
              icon: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              onPressed: () => _toggleSelection(card),
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(colors: card.gradient),
              ),
              child: Icon(card.icon, color: Colors.white, size: 20),
            ),
      title: Text(
        card.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(card.subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: isEditMode
          ? null
          : const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: () {
        if (isEditMode) {
          _toggleSelection(card);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpiredPassDetailsView(cardData: card),
            ),
          );
        }
      },
    );
  }

  void _toggleSelection(CardData card) {
    setState(() {
      if (selectedCards.contains(card.title)) {
        selectedCards.remove(card.title);
      } else {
        selectedCards.add(card.title);
      }
    });
  }

  void _toggleSelectAll() {
    final expiredCards = ref.read(expiredCardsProvider);
    setState(() {
      if (selectedCards.length == expiredCards.length) {
        selectedCards.clear();
      } else {
        selectedCards = expiredCards.map((c) => c.title).toSet();
      }
    });
  }

  void _deleteSelected() {
    final expiredCards = ref.read(expiredCardsProvider);
    final cardsToDelete = expiredCards
        .where((c) => selectedCards.contains(c.title))
        .toList();

    for (var card in cardsToDelete) {
      ref.read(cardStateProvider.notifier).deleteCard(card);
    }
    setState(() {
      selectedCards.clear();
      isEditMode = false;
    });
  }

  void _unhideSelected() {
    final expiredCards = ref.read(expiredCardsProvider);
    final cardsToUnhide = expiredCards
        .where((c) => selectedCards.contains(c.title))
        .toList();

    for (var card in cardsToUnhide) {
      ref.read(cardStateProvider.notifier).toggleCardExpired(card);
    }
    setState(() {
      selectedCards.clear();
      isEditMode = false;
    });
  }
}
