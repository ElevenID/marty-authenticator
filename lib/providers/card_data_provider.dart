import 'package:flutter/material.dart';
import '../models/card_data.dart';

class CardDataProvider {
  static List<Map<String, dynamic>> getInitialCardTypes() {
    return [
      {
        'title': 'Authentication Cards',
        'cards': [
          {
            'title': 'Work Authentication',
            'subtitle': 'Corporate access card',
            'icon': Icons.security,
            'color': Colors.blue,
            'gradient': [Colors.blue.shade300, Colors.blue.shade600],
          },
          {
            'title': 'Personal Authentication',
            'subtitle': 'Personal account access',
            'icon': Icons.security,
            'color': Colors.blue,
            'gradient': [Colors.blue.shade400, Colors.blue.shade700],
          },
          {
            'title': 'Banking Authentication',
            'subtitle': 'Secure banking access',
            'icon': Icons.security,
            'color': Colors.blue,
            'gradient': [Colors.blue.shade200, Colors.blue.shade500],
          },
        ],
      },
      {
        'title': 'Digital Wallets',
        'cards': [
          {
            'title': 'Primary Wallet',
            'subtitle': 'Main digital credentials',
            'icon': Icons.account_balance_wallet,
            'color': Colors.green,
            'gradient': [Colors.green.shade300, Colors.green.shade600],
          },
          {
            'title': 'Travel Wallet',
            'subtitle': 'Travel documents',
            'icon': Icons.account_balance_wallet,
            'color': Colors.green,
            'gradient': [Colors.green.shade400, Colors.green.shade700],
          },
        ],
      },
      {
        'title': 'Identity Verification',
        'cards': [
          {
            'title': 'Government ID',
            'subtitle': 'Official identity verification',
            'icon': Icons.verified_user,
            'color': Colors.purple,
            'gradient': [Colors.purple.shade300, Colors.purple.shade600],
          },
        ],
      },
      {
        'title': 'Transit Passes',
        'cards': [
          {
            'title': 'Metro Pass',
            'subtitle': 'City metro access',
            'icon': Icons.train,
            'color': Colors.orange,
            'gradient': [Colors.orange.shade300, Colors.orange.shade600],
          },
          {
            'title': 'Bus Pass',
            'subtitle': 'Public bus access',
            'icon': Icons.directions_bus,
            'color': Colors.orange,
            'gradient': [Colors.orange.shade400, Colors.orange.shade700],
          },
          {
            'title': 'Student Transit',
            'subtitle': 'Student discount pass',
            'icon': Icons.school,
            'color': Colors.orange,
            'gradient': [Colors.orange.shade200, Colors.orange.shade500],
          },
        ],
      },
      {
        'title': 'Driver Licenses',
        'cards': [
          {
            'title': 'Standard License',
            'subtitle': 'Regular driver\'s license',
            'icon': Icons.badge,
            'color': Colors.red,
            'gradient': [Colors.red.shade300, Colors.red.shade600],
          },
          {
            'title': 'Commercial License',
            'subtitle': 'Commercial driving permit',
            'icon': Icons.local_shipping,
            'color': Colors.red,
            'gradient': [Colors.red.shade400, Colors.red.shade700],
          },
        ],
      },
    ];
  }

  static List<CardGroup> getCardGroups() {
    return getInitialCardTypes()
        .map((groupMap) => CardGroup.fromMap(groupMap))
        .toList();
  }
}
