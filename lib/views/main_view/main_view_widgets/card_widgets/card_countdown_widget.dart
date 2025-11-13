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
import 'dart:math' as math;

/// A circular progress indicator widget for credential cards showing time-based information
/// Can be used for credential expiry countdowns, validity periods, etc.
class CardCountdownWidget extends StatelessWidget {
  final int period;
  final double secondsUntilNextOTP;
  final Color color;
  final double size;
  final double strokeWidth;

  const CardCountdownWidget({
    super.key,
    required this.period,
    required this.secondsUntilNextOTP,
    this.color = Colors.white,
    this.size = 40.0,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsUntilNextOTP / period;
    final remainingSeconds = secondsUntilNextOTP.ceil();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: _CountdownPainter(
              progress: 1.0,
              color: color.withOpacity(0.2),
              strokeWidth: strokeWidth,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: Size(size, size),
            painter: _CountdownPainter(
              progress: progress,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          // Time text
          Text(
            remainingSeconds.toString(),
            style: TextStyle(
              color: color,
              fontSize: size * 0.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CountdownPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the arc from top, clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      2 * math.pi * progress, // Progress amount
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is _CountdownPainter &&
        (oldDelegate.progress != progress || oldDelegate.color != color);
  }
}

/// A linear countdown progress bar for cards
class LinearCardCountdownWidget extends StatelessWidget {
  final int period;
  final double secondsUntilNextOTP;
  final Color color;
  final double height;
  final BorderRadius? borderRadius;

  const LinearCardCountdownWidget({
    super.key,
    required this.period,
    required this.secondsUntilNextOTP,
    this.color = Colors.white,
    this.height = 4.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsUntilNextOTP / period;
    final remainingSeconds = secondsUntilNextOTP.ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${remainingSeconds}s',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
