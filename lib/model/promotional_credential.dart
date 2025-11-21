/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';

/// Promotional credential that appears at the top of the credentials list
/// These are informational cards that can be dismissed by the user
class PromotionalCredential {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isDismissed;
  final DateTime? expiresAt;

  const PromotionalCredential({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.isDismissed = false,
    this.expiresAt,
  });

  /// Check if this promotional credential is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if this promotional credential is active (not dismissed and not expired)
  bool get isActive => !isDismissed && !isExpired;

  /// Issuer name for grouping - all promotional cards use the same "issuer"
  String get issuerName => 'PrivacyIDEA Wallet';

  /// Create a copy with modified properties
  PromotionalCredential copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    IconData? icon,
    List<Color>? gradientColors,
    bool? isDismissed,
    DateTime? expiresAt,
  }) {
    return PromotionalCredential(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      gradientColors: gradientColors ?? this.gradientColors,
      isDismissed: isDismissed ?? this.isDismissed,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromotionalCredential &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PromotionalCredential(id: $id, title: $title)';
}

/// Default promotional credentials
class DefaultPromotionalCredentials {
  static const List<PromotionalCredential> all = [
    PromotionalCredential(
      id: 'welcome',
      title: 'Welcome to Your',
      subtitle: 'Digital Wallet',
      description:
          'Store your digital credentials securely and access them anywhere.',
      icon: Icons.wallet_outlined,
      gradientColors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
    ),
    PromotionalCredential(
      id: 'security',
      title: 'Enhanced Security',
      subtitle: 'End-to-End Encryption',
      description:
          'Your data is protected with military-grade encryption and biometric authentication.',
      icon: Icons.security_outlined,
      gradientColors: [Color(0xFF50C878), Color(0xFF3A9B5C)],
    ),
    PromotionalCredential(
      id: 'features',
      title: 'New Features',
      subtitle: 'Mobile Driver\'s License',
      description:
          'Add your driver\'s license and use it for quick verification at participating locations.',
      icon: Icons.credit_card_outlined,
      gradientColors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
    ),
    PromotionalCredential(
      id: 'qr_scan',
      title: 'Quick Setup',
      subtitle: 'Scan QR Codes',
      description:
          'Easily add new credentials by scanning QR codes from trusted issuers.',
      icon: Icons.qr_code_scanner_outlined,
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFE55A5A)],
    ),
  ];
}
