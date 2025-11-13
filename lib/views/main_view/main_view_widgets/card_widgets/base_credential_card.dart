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
import 'animated_credential_card.dart';

/// Base verifiable credential card widget that provides the card-like appearance
/// similar to Apple Wallet cards with rounded corners, shadows, and proper spacing.
/// This is designed for verifiable credentials (VCs), digital identity documents,
/// certificates, and other credential types - NOT for authentication tokens.
class BaseCredentialCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final double elevation;
  final EdgeInsets margin;
  final EdgeInsets padding;

  const BaseCredentialCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.gradientColors,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.elevation = 4.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors based on theme
    final defaultBackgroundColor = isDark ? Colors.grey[900]! : Colors.white;

    final shadowColor = isDark
        ? Colors.black.withOpacity(0.6)
        : Colors.black.withOpacity(0.2);

    final cardWidget = Container(
      margin: margin,
      child: Material(
        elevation: elevation,
        shadowColor: shadowColor,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            gradient: gradientColors != null
                ? LinearGradient(
                    colors: gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: gradientColors == null
                ? backgroundColor ?? defaultBackgroundColor
                : null,
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2.0)
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    // Wrap with animated interactions if callbacks are provided
    if (onTap != null || onLongPress != null) {
      return AnimatedCredentialCard(
        onTap: onTap,
        onLongPress: onLongPress,
        child: InkWell(
          onTap: null, // Let AnimatedCredentialCard handle the tap
          borderRadius: BorderRadius.circular(16.0),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

/// Card header widget for displaying issuer and label information
class CredentialCardHeader extends StatelessWidget {
  final String issuer;
  final String label;
  final String? imageUrl;
  final IconData? fallbackIcon;
  final TextStyle? issuerStyle;
  final TextStyle? labelStyle;

  const CredentialCardHeader({
    super.key,
    required this.issuer,
    required this.label,
    this.imageUrl,
    this.fallbackIcon = Icons.security,
    this.issuerStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo/Icon section
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.white.withOpacity(0.2),
          ),
          child: imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(fallbackIcon, color: Colors.white, size: 24),
                  ),
                )
              : Icon(fallbackIcon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        // Text section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                issuer.isEmpty ? 'Unknown Issuer' : issuer,
                style:
                    issuerStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label.isEmpty ? 'Unknown Account' : label,
                style:
                    labelStyle ??
                    theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card footer widget for displaying credential information and actions
class CredentialCardFooter extends StatelessWidget {
  final String? primaryValue;
  final String? secondaryValue;
  final Widget? actionWidget;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final TextStyle? primaryValueStyle;
  final TextStyle? secondaryValueStyle;
  final bool isHidden;
  final List<Widget>? additionalActions;

  const CredentialCardFooter({
    super.key,
    this.primaryValue,
    this.secondaryValue,
    this.actionWidget,
    this.onPrimaryTap,
    this.onSecondaryTap,
    this.primaryValueStyle,
    this.secondaryValueStyle,
    this.isHidden = false,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary value section
        if (primaryValue != null)
          GestureDetector(
            onTap: onPrimaryTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isHidden ? '••••••••' : primaryValue!,
                style:
                    primaryValueStyle ??
                    theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Secondary value and action section
        if (secondaryValue != null || actionWidget != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Secondary value
              if (secondaryValue != null)
                Expanded(
                  child: GestureDetector(
                    onTap: onSecondaryTap,
                    child: Text(
                      secondaryValue!,
                      style:
                          secondaryValueStyle ??
                          theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),
                  ),
                ),

              // Action widget
              if (actionWidget != null) actionWidget!,
            ],
          ),
        ],

        // Additional actions
        if (additionalActions != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: additionalActions!,
          ),
        ],

        // Tap hint for primary value
        if (onPrimaryTap != null && primaryValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Tap to view details',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
      ],
    );
  }
}
