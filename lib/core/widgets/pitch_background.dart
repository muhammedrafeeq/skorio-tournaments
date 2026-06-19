import 'package:flutter/material.dart';

class PitchBackground extends StatelessWidget {
  final Widget child;

  const PitchBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: FootballPitchPainter(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class FootballPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Scale factors matching web SVG (800×600 viewBox)
    final sx = size.width / 800;
    final sy = size.height / 600;

    // Boundary rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10 * sx, 10 * sy, 780 * sx, 580 * sy),
        const Radius.circular(4),
      ),
      paint,
    );

    // Halfway line
    canvas.drawLine(Offset(400 * sx, 10 * sy), Offset(400 * sx, 590 * sy), paint);

    // Center circle
    canvas.drawCircle(Offset(400 * sx, 300 * sy), 80 * sx, paint);

    // Center dot
    canvas.drawCircle(
      Offset(400 * sx, 300 * sy),
      3 * sx,
      Paint()..color = Colors.white.withValues(alpha: 0.03),
    );

    // Left penalty area
    canvas.drawRect(Rect.fromLTWH(10 * sx, 150 * sy, 120 * sx, 300 * sy), paint);

    // Left goal area
    canvas.drawRect(Rect.fromLTWH(10 * sx, 220 * sy, 40 * sx, 160 * sy), paint);

    // Left penalty arc: M 130 260 A 40 40 0 0 1 130 340
    final leftArcRect = Rect.fromCenter(
      center: Offset(130 * sx, 300 * sy),
      width: 80 * sx,
      height: 80 * sy,
    );
    canvas.drawArc(leftArcRect, -1.0472, 2.0944, false, paint); // ~-60° to 60° (right-facing arc)

    // Right penalty area
    canvas.drawRect(Rect.fromLTWH(670 * sx, 150 * sy, 120 * sx, 300 * sy), paint);

    // Right goal area
    canvas.drawRect(Rect.fromLTWH(750 * sx, 220 * sy, 40 * sx, 160 * sy), paint);

    // Right penalty arc: M 670 260 A 40 40 0 0 0 670 340
    final rightArcRect = Rect.fromCenter(
      center: Offset(670 * sx, 300 * sy),
      width: 80 * sx,
      height: 80 * sy,
    );
    canvas.drawArc(rightArcRect, 2.0944, 2.0944, false, paint); // ~120° to 240° (left-facing arc)
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
