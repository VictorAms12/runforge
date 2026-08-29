import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 92,
    this.strokeWidth = 9,
    this.child,
    this.color,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: value,
              strokeWidth: strokeWidth,
              color: color ?? Theme.of(context).colorScheme.primary,
              trackColor: Colors.white.withValues(alpha: .08),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
