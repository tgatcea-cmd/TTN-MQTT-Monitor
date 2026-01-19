import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/cyber_theme.dart';

// 1. Sci-Fi Arc Gauge
class SciFiGauge extends StatelessWidget {
  final double value; // 0 to 100
  final double max;
  final String label;
  final String unit;
  final Color color;

  const SciFiGauge({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: CustomPaint(
            painter: _ArcPainter(percentage: value / max, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: 1.seconds,
                    curve: Curves.easeOutExpo,
                    builder: (context, val, _) => Text(
                      val.toStringAsFixed(1),
                      style: CyberTheme.theme.textTheme.displayMedium!.copyWith(
                        color: color,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  Text(unit, style: CyberTheme.theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: CyberTheme.theme.textTheme.labelSmall),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double percentage;
  final Color color;

  _ArcPainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    
    // Background Arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;
      
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75, 
      pi * 1.5,  
      false,
      bgPaint,
    );

    // Active Arc
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5 * percentage.clamp(0.0, 1.0),
      false,
      activePaint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 2. Animated Grid Background
class GridBackground extends StatelessWidget {
  // CORRECCIÓN: Constructor const explícito y key
  const GridBackground({super.key}); 

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: Container(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberTheme.neonSafe.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 3. Retro Terminal Line
class TerminalLine extends StatelessWidget {
  final String text;
  final int index;

  const TerminalLine({super.key, required this.text, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: CyberTheme.theme.textTheme.labelSmall!.copyWith(
          color: index == 0 ? CyberTheme.neonSafe : CyberTheme.textDim,
          fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1);
  }
}