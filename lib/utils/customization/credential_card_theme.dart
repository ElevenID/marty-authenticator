/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *          Frank Merkel <frank.merkel@netknights.it>
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

/// Theme extension for credential card styling
@immutable
class CredentialCardTheme extends ThemeExtension<CredentialCardTheme> {
  final Color cardBackgroundColor;
  final Color cardShadowColor;
  final double cardElevation;
  final double cardBorderRadius;
  final EdgeInsets cardPadding;
  final EdgeInsets cardMargin;

  // Gradient colors for different credential types
  final List<Color> defaultGradient;
  final List<Color> educationGradient;
  final List<Color> identityGradient;
  final List<Color> licenseGradient;
  final List<Color> certificateGradient;
  final List<Color> membershipGradient;
  final List<Color> employmentGradient;

  // Text colors for cards
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color hintTextColor;

  // Status colors
  final Color validStatusColor;
  final Color expiredStatusColor;
  final Color invalidStatusColor;

  const CredentialCardTheme({
    required this.cardBackgroundColor,
    required this.cardShadowColor,
    required this.cardElevation,
    required this.cardBorderRadius,
    required this.cardPadding,
    required this.cardMargin,
    required this.defaultGradient,
    required this.educationGradient,
    required this.identityGradient,
    required this.licenseGradient,
    required this.certificateGradient,
    required this.membershipGradient,
    required this.employmentGradient,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.hintTextColor,
    required this.validStatusColor,
    required this.expiredStatusColor,
    required this.invalidStatusColor,
  });

  @override
  CredentialCardTheme copyWith({
    Color? cardBackgroundColor,
    Color? cardShadowColor,
    double? cardElevation,
    double? cardBorderRadius,
    EdgeInsets? cardPadding,
    EdgeInsets? cardMargin,
    List<Color>? defaultGradient,
    List<Color>? educationGradient,
    List<Color>? identityGradient,
    List<Color>? licenseGradient,
    List<Color>? certificateGradient,
    List<Color>? membershipGradient,
    List<Color>? employmentGradient,
    Color? primaryTextColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? validStatusColor,
    Color? expiredStatusColor,
    Color? invalidStatusColor,
  }) {
    return CredentialCardTheme(
      cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
      cardElevation: cardElevation ?? this.cardElevation,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      cardPadding: cardPadding ?? this.cardPadding,
      cardMargin: cardMargin ?? this.cardMargin,
      defaultGradient: defaultGradient ?? this.defaultGradient,
      educationGradient: educationGradient ?? this.educationGradient,
      identityGradient: identityGradient ?? this.identityGradient,
      licenseGradient: licenseGradient ?? this.licenseGradient,
      certificateGradient: certificateGradient ?? this.certificateGradient,
      membershipGradient: membershipGradient ?? this.membershipGradient,
      employmentGradient: employmentGradient ?? this.employmentGradient,
      primaryTextColor: primaryTextColor ?? this.primaryTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      hintTextColor: hintTextColor ?? this.hintTextColor,
      validStatusColor: validStatusColor ?? this.validStatusColor,
      expiredStatusColor: expiredStatusColor ?? this.expiredStatusColor,
      invalidStatusColor: invalidStatusColor ?? this.invalidStatusColor,
    );
  }

  @override
  CredentialCardTheme lerp(
    ThemeExtension<CredentialCardTheme>? other,
    double t,
  ) {
    if (other is! CredentialCardTheme) {
      return this;
    }

    return CredentialCardTheme(
      cardBackgroundColor: Color.lerp(
        cardBackgroundColor,
        other.cardBackgroundColor,
        t,
      )!,
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
      cardBorderRadius: lerpDouble(
        cardBorderRadius,
        other.cardBorderRadius,
        t,
      )!,
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
      cardMargin: EdgeInsets.lerp(cardMargin, other.cardMargin, t)!,
      defaultGradient: _lerpGradient(defaultGradient, other.defaultGradient, t),
      educationGradient: _lerpGradient(
        educationGradient,
        other.educationGradient,
        t,
      ),
      identityGradient: _lerpGradient(
        identityGradient,
        other.identityGradient,
        t,
      ),
      licenseGradient: _lerpGradient(licenseGradient, other.licenseGradient, t),
      certificateGradient: _lerpGradient(
        certificateGradient,
        other.certificateGradient,
        t,
      ),
      membershipGradient: _lerpGradient(
        membershipGradient,
        other.membershipGradient,
        t,
      ),
      employmentGradient: _lerpGradient(
        employmentGradient,
        other.employmentGradient,
        t,
      ),
      primaryTextColor: Color.lerp(
        primaryTextColor,
        other.primaryTextColor,
        t,
      )!,
      secondaryTextColor: Color.lerp(
        secondaryTextColor,
        other.secondaryTextColor,
        t,
      )!,
      hintTextColor: Color.lerp(hintTextColor, other.hintTextColor, t)!,
      validStatusColor: Color.lerp(
        validStatusColor,
        other.validStatusColor,
        t,
      )!,
      expiredStatusColor: Color.lerp(
        expiredStatusColor,
        other.expiredStatusColor,
        t,
      )!,
      invalidStatusColor: Color.lerp(
        invalidStatusColor,
        other.invalidStatusColor,
        t,
      )!,
    );
  }

  List<Color> _lerpGradient(List<Color> a, List<Color> b, double t) {
    if (a.length != b.length) return a;
    return List.generate(
      a.length,
      (index) => Color.lerp(a[index], b[index], t)!,
    );
  }

  /// Light theme for credential cards
  static const CredentialCardTheme light = CredentialCardTheme(
    cardBackgroundColor: Colors.white,
    cardShadowColor: Color(0x1A000000),
    cardElevation: 4.0,
    cardBorderRadius: 16.0,
    cardPadding: EdgeInsets.all(20.0),
    cardMargin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    defaultGradient: [Color(0xFF6B73FF), Color(0xFF9575FF)],
    educationGradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    identityGradient: [Color(0xFF7B1FA2), Color(0xFFBA68C8)],
    licenseGradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    certificateGradient: [Color(0xFFEF6C00), Color(0xFFFFB74D)],
    membershipGradient: [Color(0xFF00695C), Color(0xFF4DB6AC)],
    employmentGradient: [Color(0xFF283593), Color(0xFF7986CB)],
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xCCFFFFFF),
    hintTextColor: Color(0x99FFFFFF),
    validStatusColor: Color(0xFF4CAF50),
    expiredStatusColor: Color(0xFFFF9800),
    invalidStatusColor: Color(0xFFE53935),
  );

  /// Dark theme for credential cards
  static const CredentialCardTheme dark = CredentialCardTheme(
    cardBackgroundColor: Color(0xFF2C2C2C),
    cardShadowColor: Color(0x60000000),
    cardElevation: 6.0,
    cardBorderRadius: 16.0,
    cardPadding: EdgeInsets.all(20.0),
    cardMargin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    defaultGradient: [Color(0xFF5A67D8), Color(0xFF805AD5)],
    educationGradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    identityGradient: [Color(0xFF6B21A8), Color(0xFFA855F7)],
    licenseGradient: [Color(0xFF14532D), Color(0xFF22C55E)],
    certificateGradient: [Color(0xFFCA8A04), Color(0xFFFBBF24)],
    membershipGradient: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
    employmentGradient: [Color(0xFF1E40AF), Color(0xFF6366F1)],
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xCCFFFFFF),
    hintTextColor: Color(0x99FFFFFF),
    validStatusColor: Color(0xFF10B981),
    expiredStatusColor: Color(0xFFF59E0B),
    invalidStatusColor: Color(0xFFEF4444),
  );

  /// Get appropriate gradient colors for credential type
  List<Color> getGradientForCredentialType(String type) {
    final lowerType = type.toLowerCase();

    // Check for W3C VC types
    if (lowerType.contains('degree') || lowerType.contains('education')) {
      return educationGradient;
    } else if (lowerType.contains('id') || lowerType.contains('identity')) {
      return identityGradient;
    } else if (lowerType.contains('license') || lowerType.contains('driver')) {
      return licenseGradient;
    } else if (lowerType.contains('certificate') ||
        lowerType.contains('certification')) {
      return certificateGradient;
    } else if (lowerType.contains('membership')) {
      return membershipGradient;
    } else if (lowerType.contains('employment') || lowerType.contains('work')) {
      return employmentGradient;
    }
    // Check for mDoc types
    else if (lowerType.contains('org.iso.18013.5.1.mdl')) {
      return licenseGradient; // Driving license
    } else if (lowerType.contains('org.iso.18013.5.1.mid')) {
      return identityGradient; // ID document
    } else if (lowerType.contains('org.iso.18013.5.1.mpassport')) {
      return certificateGradient; // Passport
    } else {
      return defaultGradient;
    }
  }

  /// Get color for credential status
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'revoked':
      case 'invalid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Helper function to get the card theme from context
extension CredentialCardThemeExtension on BuildContext {
  CredentialCardTheme get credentialCardTheme {
    return Theme.of(this).extension<CredentialCardTheme>() ??
        CredentialCardTheme.light;
  }
}

/// Utility function to add lerp support for double
double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
