import 'dart:math';
import 'package:flutter/material.dart';

class RingChart extends StatelessWidget {
  final double value; // 0~100
  final String label;
  final Color color;
  final String subtitle;

  const RingChart({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            painter: _RingPainter(value: value, color: color),
            child: Center(
              child: Text(
                '${value.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: const Color(0xFF686F78))),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;

    // 背景圆环
    final bgPaint = Paint()
      ..color = const Color(0xFFE9ECF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final angle = 2 * pi * (value / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // 从12点钟方向开始
      angle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}
