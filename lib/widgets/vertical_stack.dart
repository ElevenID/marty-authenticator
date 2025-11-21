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

/// Widget that creates a vertical stacking effect using Transform.translate
/// Based on the wallet stacked cards pattern from flutter_intro_wallet_UI
class VerticalStack extends StatelessWidget {
  final double dy; // Vertical spacing between cards
  final int order; // Stack order (0 = top, higher = lower in stack)
  final Widget child; // The widget to be stacked

  const VerticalStack({
    super.key,
    required this.dy,
    required this.order,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -dy * order), // Key: vertical offset calculation
      child: child,
    );
  }
}
