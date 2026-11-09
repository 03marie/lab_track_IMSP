import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';

/// Style des codes `IMSP-EQ-0001` : police de l'app, chiffres à chasse fixe (alignés d'une ligne à l'autre).
const styleCode = TextStyle(
  fontFamily: 'Jakarta',
  fontWeight: FontWeight.w700,
  fontSize: 12.5,
  letterSpacing: .8,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Ligne d'équipement dans les listes.
class EquipementTile extends StatelessWidget {
  const EquipementTile(this.e, {super.key});

  final Equipement e;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final visuel = visuelCategorie(e.categorieNom);
    final lieu = [e.laboratoireNom, e.emplacement].where((s) => s.isNotEmpty).join(' · ');
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/equipement/${e.id}'),
      child: Row(
        children: [
          Hero(
            tag: 'equipement-${e.id}',
            child: GradientIcon(icone: visuel.icone, teintes: visuel.teintes),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: lab.textMuted.withValues(alpha: .6)),
                  ],
                ),
                if (lieu.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(lieu, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(e.code, style: styleCode.copyWith(color: Palette.violet)),
                    const Spacer(),
                    StatusPill.statut(e.statut, compact: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette d'une ligne pendant le chargement.
class EquipementTileSkeleton extends StatelessWidget {
  const EquipementTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Skeleton(width: 52, height: 52, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 14, width: 160),
                SizedBox(height: 8),
                Skeleton(height: 11, width: 100),
                SizedBox(height: 8),
                Skeleton(height: 11, width: 130),
              ],
            ),
          ),
          const Skeleton(width: 74, height: 22, radius: 99),
        ],
      ),
    );
  }
}

/// Anneau des statuts : un arc par statut, animé à l'apparition.
class AnneauStatuts extends StatelessWidget {
  const AnneauStatuts({super.key, required this.stats, this.taille = 120, this.epaisseur = 12, this.centre});

  final Statistiques stats;
  final double taille;
  final double epaisseur;
  final Widget? centre;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (final s in statuts.entries)
        if (stats[s.key] > 0) (stats[s.key].toDouble(), s.value.couleur),
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutQuart,
      builder: (context, t, child) => CustomPaint(
        size: Size.square(taille),
        painter: _AnneauPainter(segments, t, epaisseur),
        child: SizedBox.square(
          dimension: taille,
          child: Center(child: child),
        ),
      ),
      child: centre,
    );
  }
}

class _AnneauPainter extends CustomPainter {
  _AnneauPainter(this.segments, this.progression, this.epaisseur);

  final List<(double, Color)> segments;
  final double progression;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final zone = rect.deflate(epaisseur / 2);
    final fond = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..color = Colors.white.withValues(alpha: .14);
    canvas.drawArc(zone, 0, 2 * math.pi, false, fond);

    final total = segments.fold<double>(0, (a, s) => a + s.$1);
    if (total == 0) return;
    const ecart = .07;
    var depart = -math.pi / 2;
    for (final (valeur, couleur) in segments) {
      final balayage = 2 * math.pi * valeur / total;
      final visible = math.max(0.0, (balayage - (segments.length > 1 ? ecart : 0)) * progression);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..color = couleur;
      canvas.drawArc(zone, depart + ecart / 2, visible, false, p);
      depart += balayage;
    }
  }

  @override
  bool shouldRepaint(_AnneauPainter old) => old.progression != progression || old.segments != segments;
}
