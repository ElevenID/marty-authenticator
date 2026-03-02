import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/card_data.dart';
import '../interfaces/spruce_interfaces.dart';
import '../services/spruce_platform_service.dart';
import '../services/wallet_credential_store.dart';
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

  /// Loads all credentials from both the Spruce SDK channel and the
  /// OID4VCI [WalletCredentialStore], then groups them by issuer.
  Future<void> loadCards() async {
    Logger.debug('DEBUG: loadCards called');
    final List<CardData> allCards = [];

    // 1. Load from Spruce SDK native channel (legacy / third-party wallets).
    try {
      final credentials = await _spruceService.getStoredCredentials();
      Logger.debug(
        'DEBUG: Loaded ${credentials.length} credentials from Spruce channel',
      );
      allCards.addAll(credentials.map(_mapCredentialToCardData));
    } catch (e) {
      Logger.error('Error loading credentials from SpruceID: $e');
    }

    // 2. Load OID4VCI-issued credentials from WalletCredentialStore.
    try {
      final stored = await WalletCredentialStore.getAll();
      Logger.debug(
        'DEBUG: Loaded ${stored.length} credentials from WalletCredentialStore',
      );
      final existingIds =
          allCards.map((c) => c.id).whereType<String>().toSet();
      for (final cred in stored) {
        if (!existingIds.contains(cred.id)) {
          allCards.add(_mapStoredCredentialToCardData(cred));
        }
      }
    } catch (e) {
      Logger.error('Error loading credentials from WalletCredentialStore: $e');
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

    state = groupedCards.entries
        .map((e) => CardGroup(title: e.key, cards: e.value))
        .toList();
    Logger.debug(
      'DEBUG: CardStateNotifier state updated with ${state.length} groups',
    );
  }

  /// Refreshes the wallet card list from all credential sources.
  Future<void> refreshCards() => loadCards();

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

  Future<void> deleteCard(CardData card) async {
    List<CardGroup> newGroups = [];
    for (var group in state) {
      final newCards = List<CardData>.from(group.cards);
      newCards.removeWhere((c) => c.title == card.title);
      newGroups.add(group.copyWith(cards: newCards));
    }
    state = newGroups;
    saveCards();
    // Also remove from WalletCredentialStore if issued via OID4VCI.
    if (card.rawData?['_source'] == 'wallet_credential_store' &&
        card.id != null) {
      try {
        await WalletCredentialStore.delete(card.id!);
      } catch (e) {
        Logger.error('Failed to delete OID4VCI credential from store: $e');
      }
    }
  }
}
