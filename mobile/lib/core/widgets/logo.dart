import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Logo LabTrack : un code-barres stylisé traversé par un faisceau de scan doré.
class LogoLabTrack extends StatefulWidget {
  const LogoLabTrack({super.key, this.taille = 84, this.anime = true});

  final double taille;
  final bool anime;

  @override
  State<LogoLabTrack> createState() => _LogoLabTrackState();
}

class _LogoLabTrackState extends State<LogoLabTrack> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.anime) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.taille;
    return Container(
      width: t,
      height: t,
      decoration: BoxDecoration(
        gradient: Palette.signatureSoft,
        borderRadius: BorderRadius.circular(t * .3),
        boxShadow: [
          BoxShadow(
            color: Palette.iris.withValues(alpha: .55),
            blurRadius: t * .5,
            offset: Offset(0, t * .18),
            spreadRadius: -t * .12,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
        builder: (context, _) => CustomPaint(painter: _LogoPainter(_ctrl.value)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.progression);
  final double progression;

  // Largeurs relatives des barres (motif fixe, évoque un Code 128).
  static const _barres = [2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2];

  @override
  void paint(Canvas canvas, Size size) {
    final zone = Rect.fromLTWH(size.width * .22, size.height * .26, size.width * .56, size.height * .48);
    final unite = zone.width / (_barres.reduce((a, b) => a + b) + _barres.length - 1);
    final blanc = Paint()..color = Colors.white;
    var x = zone.left;
    for (final b in _barres) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, zone.top, b * unite, zone.height), Radius.circular(unite * .4)),
        blanc,
      );
      x += (b + 1) * unite;
    }

    // Faisceau de scan
    final y = zone.top - 4 + (zone.height + 8) * progression;
    final faisceau = Paint()
      ..shader = const LinearGradient(colors: [Color(0x00F2C46D), Palette.gold, Color(0x00F2C46D)])
          .createShader(Rect.fromLTWH(size.width * .12, y - 2, size.width * .76, 4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .12, y - 1.5, size.width * .76, 3), const Radius.circular(2)),
      faisceau,
    );
    canvas.drawCircle(
      Offset(size.width / 2, y),
      size.width * .18,
      Paint()
        ..color = Palette.gold.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progression != progression;
}
