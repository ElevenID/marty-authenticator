import 'package:flutter/material.dart';
import 'lib/models/card_data.dart';

void main() {
  final map = {
    'title': 'Test',
    'subtitle': 'Subtitle',
    'icon': Icons.add,
    'color': Colors.red,
    'gradient': [Colors.red, Colors.blue],
    'sortOrder': 1,
    // 'isExpired' is missing
  };

  try {
    final card = CardData.fromMap(map);
    print('Success: isExpired = ${card.isExpired}');
  } catch (e) {
    print('Error: $e');
  }
}
