import 'package:flutter/material.dart';
import '../utils/layout_constants.dart';

class NotificationCardData {
  final String title;
  final String subtitle;
  final Widget icon;
  final Color color;
  final VoidCallback? onTap;

  NotificationCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class StackedNotificationCards extends StatefulWidget {
  final List<NotificationCardData> notifications;

  const StackedNotificationCards({super.key, required this.notifications});

  @override
  State<StackedNotificationCards> createState() =>
      _StackedNotificationCardsState();
}

class _StackedNotificationCardsState extends State<StackedNotificationCards> {
  bool _expanded = false;
  List<NotificationCardData>? _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.from(widget.notifications);
  }

  @override
  Widget build(BuildContext context) {
    // Initialize if null (handles hot reload case)
    _notifications ??= List.from(widget.notifications);

    if (_notifications!.isEmpty) return const SizedBox.shrink();

    // Calculate height based on expanded state
    final double itemHeight = LayoutConstants.notificationCardHeight;
    final double spacing = 10.0;
    final double collapsedHeight = itemHeight + 40.0;
    final double expandedHeight =
        (itemHeight + spacing) * _notifications!.length + 20.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _expanded ? expandedHeight : collapsedHeight,
      margin: const EdgeInsets.only(bottom: 20, top: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // We render the list in reverse order so the first item (index 0) is rendered last (on top)
          ...List.generate(_notifications!.length, (index) {
            // We want index 0 to be on top.
            // In Stack, children are painted bottom-up. Last child is on top.
            // So we want index 0 to be the last child in this list.
            int renderIndex = _notifications!.length - 1 - index;
            NotificationCardData data = _notifications![renderIndex];

            double collapsedTop = renderIndex * 10.0;
            double expandedTop = renderIndex * (itemHeight + spacing);

            double collapsedScale = 1.0 - (renderIndex * 0.05);
            if (collapsedScale < 0.8) collapsedScale = 0.8;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _expanded ? expandedTop : collapsedTop,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  scale: _expanded ? 1.0 : collapsedScale,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: _buildCard(data, renderIndex),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCard(NotificationCardData data, int index) {
    return Container(
      height: LayoutConstants.notificationCardHeight,
      width: LayoutConstants.cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: data.icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_expanded)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _notifications!.removeAt(index);
                  if (_notifications!.isEmpty) {
                    _expanded = false;
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}
