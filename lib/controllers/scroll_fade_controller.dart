import 'package:flutter/material.dart';

class ScrollFadeController {
  final ScrollController scrollController = ScrollController();
  double _headerOpacity = 1.0;
  final double fadeDistance;
  final VoidCallback? onOpacityChanged;

  ScrollFadeController({this.fadeDistance = 100.0, this.onOpacityChanged});

  double get headerOpacity => _headerOpacity;

  void initialize() {
    scrollController.addListener(_onScroll);
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
  }

  void _onScroll() {
    final scrollOffset = scrollController.offset;
    final newOpacity = (1.0 - (scrollOffset / fadeDistance)).clamp(0.0, 1.0);

    if (_headerOpacity != newOpacity) {
      _headerOpacity = newOpacity;
      onOpacityChanged?.call();
    }
  }
}
