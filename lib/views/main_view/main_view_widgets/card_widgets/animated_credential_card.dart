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
import 'package:flutter/services.dart';

/// Enhanced card widget with Apple Wallet-style animations and interactions
class AnimatedCredentialCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final bool isExpanded;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedCredentialCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.isExpanded = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  });

  @override
  State<AnimatedCredentialCard> createState() => _AnimatedCredentialCardState();
}

class _AnimatedCredentialCardState extends State<AnimatedCredentialCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _expandController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _expandAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _expandController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: widget.animationCurve),
    );

    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandController, curve: widget.animationCurve),
    );
  }

  @override
  void didUpdateWidget(AnimatedCredentialCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    widget.onDoubleTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: _handleLongPress,
      onDoubleTap: widget.onDoubleTap != null ? _handleDoubleTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _expandAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: widget.animationDuration,
              curve: widget.animationCurve,
              transform: Matrix4.identity()
                ..translate(0.0, _isPressed ? 2.0 : 0.0),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Card interaction manager for handling complex gestures and animations
class CardInteractionManager extends StatefulWidget {
  final List<Widget> cards;
  final Function(int)? onCardTap;
  final Function(int)? onCardLongPress;
  final Function(int, int)? onCardsReorder;
  final EdgeInsets padding;
  final bool allowReordering;
  final bool stackCards;

  const CardInteractionManager({
    super.key,
    required this.cards,
    this.onCardTap,
    this.onCardLongPress,
    this.onCardsReorder,
    this.padding = const EdgeInsets.all(8.0),
    this.allowReordering = false,
    this.stackCards = false,
  });

  @override
  State<CardInteractionManager> createState() => _CardInteractionManagerState();
}

class _CardInteractionManagerState extends State<CardInteractionManager>
    with TickerProviderStateMixin {
  int? _draggedIndex;
  int? _hoveredIndex;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.cards.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _animations = _controllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        )
        .toList();
  }

  @override
  void didUpdateWidget(CardInteractionManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cards.length != oldWidget.cards.length) {
      // Dispose old controllers
      for (final controller in _controllers) {
        controller.dispose();
      }
      _initializeAnimations();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildCard(int index) {
    final card = widget.cards[index];

    if (widget.stackCards) {
      return _buildStackedCard(index, card);
    } else {
      return _buildRegularCard(index, card);
    }
  }

  Widget _buildRegularCard(int index, Widget card) {
    return Padding(
      padding: widget.padding,
      child: AnimatedCredentialCard(
        onTap: () => widget.onCardTap?.call(index),
        onLongPress: () => _handleLongPress(index),
        child: card,
      ),
    );
  }

  Widget _buildStackedCard(int index, Widget card) {
    final animation = _animations[index];
    final isHovered = _hoveredIndex == index;
    final isDragged = _draggedIndex == index;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final offset = index * 8.0;
        final scale = isDragged ? 1.05 : (isHovered ? 1.02 : 1.0);
        final elevation = isDragged ? 12.0 : (isHovered ? 8.0 : 4.0);

        return Transform.translate(
          offset: Offset(0, offset - (animation.value * offset)),
          child: Transform.scale(
            scale: scale,
            child: Container(
              margin: EdgeInsets.only(
                top: index == 0 ? 0 : 4,
                bottom: 4,
                left: 8,
                right: 8,
              ),
              child: Material(
                elevation: elevation,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedCredentialCard(
                  onTap: () => _handleCardTap(index),
                  onLongPress: () => _handleLongPress(index),
                  child: card,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCardTap(int index) {
    // Animate card to front of stack
    if (widget.stackCards && index != 0) {
      _controllers[index].forward();

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();

      // Move card to front after animation
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onCardsReorder?.call(index, 0);
        }
      });
    } else {
      widget.onCardTap?.call(index);
    }
  }

  void _handleLongPress(int index) {
    HapticFeedback.heavyImpact();

    if (widget.allowReordering) {
      setState(() => _draggedIndex = index);
    }

    widget.onCardLongPress?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allowReordering) {
      return ReorderableListView.builder(
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          widget.onCardsReorder?.call(oldIndex, newIndex);
        },
        itemCount: widget.cards.length,
        itemBuilder: (context, index) => _buildCard(index),
      );
    } else {
      return ListView.builder(
        itemCount: widget.cards.length,
        itemBuilder: (context, index) => _buildCard(index),
      );
    }
  }
}

/// Utility class for card animations and transitions
class CardAnimationUtils {
  static Widget slideInCard({
    required Widget child,
    required AnimationController controller,
    Offset beginOffset = const Offset(1.0, 0.0),
    Curve curve = Curves.easeInOut,
  }) {
    final slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: curve));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: curve));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  static Widget flipCard({
    required Widget frontCard,
    required Widget backCard,
    required AnimationController controller,
  }) {
    final flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: flipAnimation,
      builder: (context, child) {
        final isShowingFront = flipAnimation.value < 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(flipAnimation.value * 3.14159),
          child: isShowingFront
              ? frontCard
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: backCard,
                ),
        );
      },
    );
  }
}
