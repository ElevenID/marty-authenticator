import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/card_data.dart';
import '../interfaces/spruce_interfaces.dart';
import '../services/spruce_platform_service.dart';
import '../utils/logger.dart';

final cardStateProvider =
    StateNotifierProvider<CardStateNotifier, List<CardGroup>>((ref) {
      final spruceService = ref.watch(spruceIdPlatformServiceProvider);
      return CardStateNotifier(spruceService);
    });

final activeCardGroupsProvider = Provider<List<CardGroup>>((ref) {
  final allGroups = ref.watch(cardStateProvider);
  Logger.debug(
    'DEBUG: activeCardGroupsProvider updating. Groups: ${allGroups.length}',
  );
  return allGroups
      .map((group) {
        final activeCards = group.cards
            .where((card) => !card.isExpired)
            .toList();
        return group.copyWith(cards: activeCards);
      })
      .where((group) => group.cards.isNotEmpty)
      .toList();
});

final expiredCardsProvider = Provider<List<CardData>>((ref) {
  final allGroups = ref.watch(cardStateProvider);
  return allGroups
      .expand((group) => group.cards)
      .where((card) => card.isExpired)
      .toList();
});

final draggingCardProvider = StateProvider<CardData?>((ref) => null);

class CardStateNotifier extends StateNotifier<List<CardGroup>> {
  final ISpruceIdPlatformService _spruceService;

  CardStateNotifier(this._spruceService) : super([]) {
    loadCards();
  }

  final _storage = const FlutterSecureStorage();
  static const _storageKey = 'card_groups_data';

  Future<void> loadCards() async {
    Logger.debug('DEBUG: loadCards called');
    try {
      // Try to load from SpruceID SDK
      final credentials = await _spruceService.getStoredCredentials();
      Logger.debug('DEBUG: Loaded ${credentials.length} credentials');
      if (credentials.isNotEmpty) {
        final cards = credentials
            .map((c) => _mapCredentialToCardData(c))
            .toList();

        // Group cards by issuer
        final Map<String, List<CardData>> groupedCards = {};
        for (var card in cards) {
          final issuer = card.issuer ?? 'Unknown Issuer';
          if (!groupedCards.containsKey(issuer)) {
            groupedCards[issuer] = [];
          }
          groupedCards[issuer]!.add(card);
        }

        state = groupedCards.entries.map((entry) {
          return CardGroup(title: entry.key, cards: entry.value);
        }).toList();
        Logger.debug(
          'DEBUG: CardStateNotifier state updated with ${state.length} groups',
        );

        return;
      } else {
        // No credentials found
        Logger.debug('DEBUG: No credentials found.');
        state = [];
      }
    } catch (e) {
      Logger.error('Error loading credentials from SpruceID: $e');
      state = [];
    }
  }

  CardData _mapCredentialToCardData(Map<String, dynamic> credential) {
    // Extract fields
    final id = credential['id'] as String?;
    final type = credential['type'] as String? ?? 'Unknown';
    final issuer = credential['issuer'] as String? ?? 'Unknown Issuer';
    final data = credential['data'] as Map<String, dynamic>? ?? {};

    // Check expiration
    bool isExpired = credential['isExpired'] as bool? ?? false;
    if (!isExpired && credential.containsKey('expirationDate')) {
      try {
        final expiry = DateTime.parse(credential['expirationDate'] as String);
        isExpired = expiry.isBefore(DateTime.now());
      } catch (e) {
        // If we can't parse the date, assume not expired
        isExpired = false;
      }
    }

    // Determine UI properties based on type
    String title = type;
    IconData icon = Icons.credit_card;
    Color color = Colors.blue;
    List<Color> gradient = [Colors.blue, Colors.blueAccent];

    if (type.contains('DriverLicense') || type.contains('mDL')) {
      title = "Driver's License";
      icon = Icons.drive_eta;
      color = Colors.deepPurple;
      gradient = [Colors.deepPurple, Colors.purpleAccent];
    } else if (type.contains('VerifiableId')) {
      title = "Digital ID";
      icon = Icons.perm_identity;
      color = Colors.teal;
      gradient = [Colors.teal, Colors.tealAccent];
    }

    // For now, expose all data as both metadata and privateData
    // In a real app, we would filter this based on the schema

    return CardData(
      title: title,
      subtitle: issuer,
      icon: icon,
      color: color,
      gradient: gradient,
      id: id,
      type: type,
      issuer: issuer,
      isExpired: isExpired,
      rawData: data,
      metadata: data,
      privateData: data,
    );
  }

  Future<void> saveCards() async {
    final data = jsonEncode(state.map((group) => group.toMap()).toList());
    await _storage.write(key: _storageKey, value: data);
  }

  void reorderCard(CardData card, int newGroupIndex, int newIndex) {
    List<CardGroup> newGroups = [];

    // 1. Remove card from its current position
    for (var group in state) {
      // Check if this group contains the card (by title/properties since we don't have ID)
      // Assuming card object reference might be different if reloaded, but here we pass the object.
      // Ideally we should match by ID. Since we don't have ID, we rely on object equality or title.
      // CardData uses default equality (props) if it extends Equatable, but it doesn't.
      // So it uses identity. If the passed 'card' is from the current state, it works.
      if (group.cards.contains(card)) {
        final newCards = List<CardData>.from(group.cards)..remove(card);
        newGroups.add(group.copyWith(cards: newCards));
      } else {
        newGroups.add(group);
      }
    }

    // 2. Insert card at new position
    if (newGroupIndex >= 0 && newGroupIndex < newGroups.length) {
      final targetGroup = newGroups[newGroupIndex];
      final newCards = List<CardData>.from(targetGroup.cards);

      // Clamp index
      final insertIndex = newIndex.clamp(0, newCards.length);
      newCards.insert(insertIndex, card);

      newGroups[newGroupIndex] = targetGroup.copyWith(cards: newCards);
    }

    // 3. Update sort orders
    newGroups = newGroups.map((group) {
      final updatedCards = group.cards.asMap().entries.map((entry) {
        return entry.value.copyWith(sortOrder: entry.key);
      }).toList();
      return group.copyWith(cards: updatedCards);
    }).toList();

    state = newGroups;
    saveCards();
  }

  void reorderGroup(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    if (newIndex < 0 || newIndex > state.length) return; // Allow appending

    // Adjust newIndex if removing oldIndex shifts indices
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = state[oldIndex];
    final newState = List<CardGroup>.from(state);
    newState.removeAt(oldIndex);
    newState.insert(newIndex, item);
    state = newState;
    saveCards();
  }

  void toggleCardExpired(CardData card) {
    List<CardGroup> newGroups = [];
    for (var group in state) {
      final newCards = group.cards.map((c) {
        if (c.title == card.title) {
          // Using title as ID for now
          return c.copyWith(isExpired: !c.isExpired);
        }
        return c;
      }).toList();
      newGroups.add(group.copyWith(cards: newCards));
    }
    state = newGroups;
    saveCards();
  }

  void deleteCard(CardData card) {
    List<CardGroup> newGroups = [];
    for (var group in state) {
      final newCards = List<CardData>.from(group.cards);
      newCards.removeWhere((c) => c.title == card.title);
      newGroups.add(group.copyWith(cards: newCards));
    }
    state = newGroups;
    saveCards();
  }
}
