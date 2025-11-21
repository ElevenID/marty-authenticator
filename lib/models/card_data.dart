import 'package:flutter/material.dart';

class CardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final int sortOrder;
  final bool isExpired;

  // SpruceID Credential Fields
  final String? id;
  final String? type;
  final String? issuer;
  final Map<String, dynamic>? rawData;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? privateData;

  const CardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
    this.sortOrder = 0,
    this.isExpired = false,
    this.id,
    this.type,
    this.issuer,
    this.rawData,
    this.metadata,
    this.privateData,
  });

  factory CardData.fromMap(Map<String, dynamic> map) {
    return CardData(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      icon: map['icon'] as IconData,
      color: map['color'] as Color,
      gradient: map['gradient'] as List<Color>,
      sortOrder: map['sortOrder'] as int? ?? 0,
      isExpired: map['isExpired'] as bool? ?? false,
      id: map['id'] as String?,
      type: map['type'] as String?,
      issuer: map['issuer'] as String?,
      rawData: map['rawData'] as Map<String, dynamic>?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      privateData: map['privateData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon,
      'color': color,
      'gradient': gradient,
      'sortOrder': sortOrder,
      'isExpired': isExpired,
      'id': id,
      'type': type,
      'issuer': issuer,
      'rawData': rawData,
      'metadata': metadata,
      'privateData': privateData,
    };
  }

  CardData copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
    Color? color,
    List<Color>? gradient,
    int? sortOrder,
    bool? isExpired,
    String? id,
    String? type,
    String? issuer,
    Map<String, dynamic>? rawData,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? privateData,
  }) {
    return CardData(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      sortOrder: sortOrder ?? this.sortOrder,
      isExpired: isExpired ?? this.isExpired,
      id: id ?? this.id,
      type: type ?? this.type,
      issuer: issuer ?? this.issuer,
      rawData: rawData ?? this.rawData,
      metadata: metadata ?? this.metadata,
      privateData: privateData ?? this.privateData,
    );
  }
}

class CardGroup {
  final String title;
  final List<CardData> cards;

  const CardGroup({required this.title, required this.cards});

  factory CardGroup.fromMap(Map<String, dynamic> map) {
    final cardsList = (map['cards'] as List).cast<Map<String, dynamic>>();
    return CardGroup(
      title: map['title'] as String,
      cards: cardsList.asMap().entries.map((entry) {
        final index = entry.key;
        final cardMap = Map<String, dynamic>.from(entry.value);
        // Assign sortOrder if not present, using index
        if (!cardMap.containsKey('sortOrder')) {
          cardMap['sortOrder'] = index;
        }
        return CardData.fromMap(cardMap);
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'title': title, 'cards': cards.map((x) => x.toMap()).toList()};
  }

  CardGroup copyWith({String? title, List<CardData>? cards}) {
    return CardGroup(title: title ?? this.title, cards: cards ?? this.cards);
  }
}
