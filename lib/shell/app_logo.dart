import 'package:flutter/material.dart';

/// The icon's colors, from light purple to dark.
const logoShades = [
  Color(0xFFBDA2F7),
  Color(0xFF9C7CEB),
  Color(0xFF845FDD),
  Color(0xFF6943BD),
];

/// Side of each stacked sheet, as a fraction of the icon's side, from the
/// one at the back to the one in front.
const _sheetSides = [1.0, 0.94, 0.88, 0.82];

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 24, this.outlined = false, super.key});

  final double size;

  /// Light outline so the icon does not vanish against the purple band.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: const _SheetsPainter(),
          child: Center(
            child: Text(
              'C',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.64,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Voges Click',
      child: outlined
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                border: Border.all(color: const Color(0xB3FFFFFF)),
              ),
              child: logo,
            )
          : logo,
    );
  }
}

class _SheetsPainter extends CustomPainter {
  const _SheetsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    for (var i = 0; i < _sheetSides.length; i++) {
      final sheet = side * _sheetSides[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, side - sheet, sheet, sheet),
          Radius.circular(side * 0.2),
        ),
        Paint()..color = logoShades[i],
      );
    }
  }

  @override
  bool shouldRepaint(_SheetsPainter oldDelegate) => false;
}
