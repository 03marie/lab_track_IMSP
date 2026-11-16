import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Logo LabTrack : un code-barres blanc sur un carré d'accent. Aplat, sans effet.
class LogoLabTrack extends StatelessWidget {
  const LogoLabTrack({super.key, this.taille = 72});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(taille * .24)),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  // Largeurs relatives des barres (motif fixe, évoque un Code 128).
  static const _barres = [2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2];

  @override
  void paint(Canvas canvas, Size size) {
    final zone = Rect.fromLTWH(size.width * .22, size.height * .27, size.width * .56, size.height * .46);
    final unite = zone.width / (_barres.reduce((a, b) => a + b) + _barres.length - 1);
    final blanc = Paint()..color = Colors.white;
    var x = zone.left;
    for (final b in _barres) {
      canvas.drawRect(Rect.fromLTWH(x, zone.top, b * unite, zone.height), blanc);
      x += (b + 1) * unite;
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}
