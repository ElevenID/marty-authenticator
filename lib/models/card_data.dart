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
  });

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
    );
  }
}

class CardGroup {
  final String title;
  final List<CardData> cards;

  const CardGroup({required this.title, required this.cards});

  CardGroup copyWith({String? title, List<CardData>? cards}) {
    return CardGroup(title: title ?? this.title, cards: cards ?? this.cards);
  }
}
