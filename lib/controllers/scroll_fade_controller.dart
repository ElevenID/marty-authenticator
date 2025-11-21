import 'package:flutter/material.dart';

class ScrollFadeController {
  final ScrollController scrollController = ScrollController();
  double _headerOpacity = 1.0;
  double _footerOpacity = 0.0;
  final double fadeDistance;
  final VoidCallback? onOpacityChanged;

  ScrollFadeController({this.fadeDistance = 100.0, this.onOpacityChanged});

  double get headerOpacity => _headerOpacity;
  double get footerOpacity => _footerOpacity;

  void initialize() {
    scrollController.addListener(_onScroll);
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
  }

  void _onScroll() {
    final scrollOffset = scrollController.offset.clamp(0.0, double.infinity);
    final normalizedOffset = (scrollOffset / fadeDistance).clamp(0.0, 1.0);
    final newHeaderOpacity = (1.0 - normalizedOffset).clamp(0.0, 1.0);
    final newFooterOpacity = normalizedOffset.clamp(0.0, 1.0);

    if (_headerOpacity != newHeaderOpacity ||
        _footerOpacity != newFooterOpacity) {
      _headerOpacity = newHeaderOpacity;
      _footerOpacity = newFooterOpacity;
      onOpacityChanged?.call();
    }
  }
}
