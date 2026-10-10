import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/card_data.dart';
import '../services/wallet_credential_store.dart';
import '../utils/logger.dart';

final cardStateProvider =
    StateNotifierProvider<CardStateNotifier, List<CardGroup>>((ref) {
      return CardStateNotifier();
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
  CardStateNotifier() : super([]) {
    loadCards();
  }

  final _storage = const FlutterSecureStorage();
  static const _storageKey = 'card_groups_data';
  Future<void> _lastWrite = Future.value();

  /// Loads verified OID4VCI receipts from [WalletCredentialStore] and
  /// groups them by issuer.
  Future<void> loadCards() async {
    Logger.debug('DEBUG: loadCards called');
    final List<CardData> allCards = [];

    try {
      final stored = await WalletCredentialStore.getAll();
      Logger.debug(
        'DEBUG: Loaded ${stored.length} credentials from WalletCredentialStore',
      );
      for (final cred in stored) {
        allCards.add(_mapStoredCredentialToCardData(cred));
      }
    } catch (e) {
      Logger.error('Error loading credentials from WalletCredentialStore: $e');
      return;
    }

    if (allCards.isEmpty) {
      Logger.debug('DEBUG: No credentials found.');
      state = [];
      return;
    }

    // Group by issuer.
    final Map<String, List<CardData>> groupedCards = {};
    for (final card in allCards) {
      final issuer = card.issuer ?? 'Unknown Issuer';
      groupedCards.putIfAbsent(issuer, () => []).add(card);
    }

    final groups = groupedCards.entries
        .map((e) => CardGroup(title: e.key, cards: e.value))
        .toList();
    state = await _restoreLayout(groups);
    Logger.debug(
      'DEBUG: CardStateNotifier state updated with ${state.length} groups',
    );
  }

  /// Refreshes the wallet card list from verified receipts.
  Future<void> refreshCards() => loadCards();

  /// Maps a [StoredCredential] (OID4VCI-received) to [CardData] for display.
  CardData _mapStoredCredentialToCardData(StoredCredential cred) {
    final type = cred.types.isNotEmpty ? cred.types.first : cred.format;
    final typeLower = type.toLowerCase();

    String title = type;
    IconData icon = Icons.credit_card;
    Color color = Colors.blue;
    List<Color> gradient = [Colors.blue, Colors.blueAccent];

    if (typeLower.contains('driverlicense') ||
        typeLower.contains('mdl') ||
        typeLower.contains('mso_mdoc')) {
      title = "Driver's License";
      icon = Icons.drive_eta;
      color = Colors.deepPurple;
      gradient = [Colors.deepPurple, Colors.purpleAccent];
    } else if (typeLower.contains('id') || typeLower.contains('identity')) {
      title = 'Digital ID';
      icon = Icons.perm_identity;
      color = Colors.teal;
      gradient = [Colors.teal, Colors.tealAccent];
    } else if (typeLower.contains('sd-jwt') ||
        typeLower.contains('sdjwt') ||
        typeLower.contains('jwt')) {
      title = 'Verifiable Credential';
      icon = Icons.verified_user;
      color = Colors.indigo;
      gradient = [Colors.indigo, Colors.indigoAccent];
    }

    final Map<String, dynamic> data = {
      '_source': 'wallet_credential_store',
      'format': cred.format,
      'issuedAt': cred.issuedAt.toIso8601String(),
    };

    return CardData(
      title: title,
      subtitle: cred.issuer,
      icon: icon,
      color: color,
      gradient: gradient,
      id: cred.id,
      type: type,
      issuer: cred.issuer,
      rawData: data,
      metadata: data,
    );
  }

  Future<List<CardGroup>> _restoreLayout(List<CardGroup> groups) async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return groups;
      if (raw.length > 64 * 1024) {
        throw const FormatException('Layout is too large');
      }
      final layout = jsonDecode(raw);
      if (layout is! Map<String, dynamic> ||
          layout['version'] != 1 ||
          layout['groups'] is! List ||
          layout['expired_ids'] is! List) {
        throw const FormatException('Wallet layout is invalid');
      }
      final expired = (layout['expired_ids'] as List).cast<String>().toSet();
      final current = {for (final group in groups) group.title: group};
      final restored = <CardGroup>[];
      for (final item in layout['groups'] as List) {
        if (item is! Map<String, dynamic> ||
            item['title'] is! String ||
            item['ids'] is! List) {
          throw const FormatException('Wallet group layout is invalid');
        }
        final group = current.remove(item['title']);
        if (group == null) continue;
        final byId = {for (final card in group.cards) card.id: card};
        final cards = <CardData>[];
        for (final id in (item['ids'] as List).cast<String>()) {
          final card = byId.remove(id);
          if (card != null) cards.add(card);
        }
        cards.addAll(byId.values);
        restored.add(group.copyWith(cards: cards));
      }
      restored.addAll(current.values);
      return restored
          .map(
            (group) => group.copyWith(
              cards: group.cards
                  .map(
                    (card) =>
                        card.copyWith(isExpired: expired.contains(card.id)),
                  )
                  .toList(),
            ),
          )
          .toList();
    } catch (error) {
      Logger.warning('Ignoring invalid wallet card layout: $error');
      return groups;
    }
  }

  Future<void> saveCards() {
    final data = jsonEncode({
      'version': 1,
      'groups': [
        for (final group in state)
          {
            'title': group.title,
            'ids': group.cards
                .map((card) => card.id)
                .whereType<String>()
                .toList(),
          },
      ],
      'expired_ids': [
        for (final card in state.expand((group) => group.cards))
          if (card.isExpired && card.id != null) card.id,
      ],
    });
    final write = _lastWrite.then(
      (_) => _storage.write(key: _storageKey, value: data),
    );
    _lastWrite = write.catchError((Object error) {
      Logger.error('Failed to save wallet card layout: $error');
    });
    return write;
  }

  void reorderCard(CardData card, int newGroupIndex, int newIndex) {
    final id = card.id;
    if (id == null || newGroupIndex < 0 || newGroupIndex >= state.length) {
      return;
    }
    final group = state[newGroupIndex];
    final oldIndex = group.cards.indexWhere((candidate) => candidate.id == id);
    if (oldIndex < 0) return;

    final cards = List<CardData>.from(group.cards)..removeAt(oldIndex);
    cards.insert(newIndex.clamp(0, cards.length), group.cards[oldIndex]);
    final ordered = [
      for (final (index, value) in cards.indexed)
        value.copyWith(sortOrder: index),
    ];
    final groups = List<CardGroup>.from(state);
    groups[newGroupIndex] = group.copyWith(cards: ordered);
    state = groups;
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
    final id = card.id;
    if (id == null) return;
    List<CardGroup> newGroups = [];
    for (var group in state) {
      final newCards = group.cards.map((c) {
        if (c.id == id) {
          return c.copyWith(isExpired: !c.isExpired);
        }
        return c;
      }).toList();
      newGroups.add(group.copyWith(cards: newCards));
    }
    state = newGroups;
    saveCards();
  }

  Future<void> deleteCard(CardData card) async {
    final id = card.id;
    if (id == null || card.rawData?['_source'] != 'wallet_credential_store') {
      throw StateError('Only verified wallet credentials can be deleted');
    }
    await WalletCredentialStore.delete(id);
    List<CardGroup> newGroups = [];
    for (var group in state) {
      final newCards = List<CardData>.from(group.cards);
      newCards.removeWhere((c) => c.id == id);
      newGroups.add(group.copyWith(cards: newCards));
    }
    state = newGroups;
    try {
      await saveCards();
    } catch (_) {
      // The verified receipt is already deleted; layout is only a preference.
    }
  }
}
