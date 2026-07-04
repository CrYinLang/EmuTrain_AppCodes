// speedometer_display.dart
// GPS 速度计显示组件

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 速度计表盘组件
class SpeedometerDisplay extends StatelessWidget {
  final double currentSpeed;
  final double maxSpeed;
  final String unit;

  const SpeedometerDisplay({
    super.key,
    required this.currentSpeed,
    required this.maxSpeed,
    this.unit = 'km/h',
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: _SpeedometerPainter(
        currentSpeed: currentSpeed,
        maxSpeed: maxSpeed,
        unit: unit,
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double currentSpeed;
  final double maxSpeed;
  final String unit;

  _SpeedometerPainter({
    required this.currentSpeed,
    required this.maxSpeed,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // 绘制背景刻度盘
    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // 绘制进度弧线
    final progressPaint = Paint()
      ..color = _getSpeedColor(currentSpeed, maxSpeed)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (currentSpeed / maxSpeed) * math.pi * 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );

    // 绘制刻度
    _drawTicks(canvas, center, radius);

    // 绘制中心文字
    _drawCenterText(canvas, center);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 10; i++) {
      final angle = math.pi * 0.75 + (math.pi * 1.5 * i / 10);
      final innerRadius = radius - 30;
      final outerRadius = radius - 10;

      final start = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, tickPaint);

      // 绘制数字
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(maxSpeed * i / 10).toInt()}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textRadius = radius - 50;
      final textPos = Offset(
        center.dx + textRadius * math.cos(angle) - textPainter.width / 2,
        center.dy + textRadius * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, textPos);
    }
  }

  void _drawCenterText(Canvas canvas, Offset center) {
    // 当前速度
    final speedText = TextPainter(
      text: TextSpan(
        text: '${currentSpeed.toInt()}',
        style: TextStyle(
          color: _getSpeedColor(currentSpeed, maxSpeed),
          fontSize: 56,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    speedText.layout();
    speedText.paint(
      canvas,
      Offset(center.dx - speedText.width / 2, center.dy - speedText.height / 2 - 20),
    );

    // 单位
    final unitText = TextPainter(
      text: const TextSpan(
        text: 'km/h',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    unitText.layout();
    unitText.paint(
      canvas,
      Offset(center.dx - unitText.width / 2, center.dy + 20),
    );

    // 最高速度
    final maxText = TextPainter(
      text: TextSpan(
        text: '最高 ${maxSpeed.toInt()} km/h',
        style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    );
    maxText.layout();
    maxText.paint(
      canvas,
      Offset(center.dx - maxText.width / 2, center.dy + 50),
    );
  }

  Color _getSpeedColor(double speed, double max) {
    final ratio = speed / max;
    if (ratio < 0.5) return Colors.green;
    if (ratio < 0.75) return Colors.orange;
    return Colors.red;
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.currentSpeed != currentSpeed || oldDelegate.maxSpeed != maxSpeed;
  }
}
