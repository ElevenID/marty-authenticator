import 'package:flutter/material.dart';

class CardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const CardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  factory CardData.fromMap(Map<String, dynamic> map) {
    return CardData(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      icon: map['icon'] as IconData,
      color: map['color'] as Color,
      gradient: map['gradient'] as List<Color>,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon,
      'color': color,
      'gradient': gradient,
    };
  }
}

class CardGroup {
  final String title;
  final List<CardData> cards;

  const CardGroup({required this.title, required this.cards});

  factory CardGroup.fromMap(Map<String, dynamic> map) {
    return CardGroup(
      title: map['title'] as String,
      cards: (map['cards'] as List<Map<String, dynamic>>)
          .map((cardMap) => CardData.fromMap(cardMap))
          .toList(),
    );
  }
}
