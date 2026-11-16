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
  fontWeight: FontWeight.w600,
  fontSize: 12.5,
  letterSpacing: .5,
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
      accent: visuel.couleur,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onTap: () => context.push('/equipement/${e.id}'),
      child: Row(
        children: [
          Hero(
            tag: 'equipement-${e.id}',
            child: IconeTuile(icone: visuel.icone, couleur: visuel.couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  lieu.isEmpty ? e.code : '${e.code} · $lieu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill.statut(e.statut, compact: true),
          Icon(Icons.chevron_right_rounded, color: lab.textMuted),
        ],
      ),
    );
  }
}

/// Squelette d'une ligne pendant le chargement.
class EquipementTileSkeleton extends StatelessWidget {
  const EquipementTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Skeleton(height: 68, radius: 16);
}

/// Petite carte d'équipement (grille à deux colonnes). Le filet de couleur indique la catégorie.
class EquipementCard extends StatelessWidget {
  const EquipementCard(this.e, {super.key});

  final Equipement e;

  @override
  Widget build(BuildContext context) {
    final visuel = visuelCategorie(e.categorieNom);
    final statut = apparenceStatut(e.statut);
    final lieu = e.emplacement.isNotEmpty ? e.emplacement : e.laboratoireNom;

    return SurfaceCard(
      accent: visuel.couleur,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () => context.push('/equipement/${e.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'equipement-${e.id}',
                child: IconeTuile(icone: visuel.icone, couleur: visuel.couleur, taille: 40),
              ),
              const Spacer(),
              Icon(statut.icone, size: 20, color: statut.couleur),
            ],
          ),
          const Spacer(),
          Text(e.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(height: 1.2)),
          const SizedBox(height: 2),
          Text(lieu, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(e.code.replaceFirst('IMSP-EQ-', '#'), style: styleCode.copyWith(fontSize: 11.5, color: context.lab.textMuted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statut.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: context.lisible(statut.couleur), fontWeight: FontWeight.w600, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Squelette d'une carte pendant le chargement.
class EquipementCardSkeleton extends StatelessWidget {
  const EquipementCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Skeleton(height: double.infinity, radius: 16);
}

/// Anneau des statuts : un arc par statut.
class AnneauStatuts extends StatelessWidget {
  const AnneauStatuts({super.key, required this.stats, this.taille = 104, this.epaisseur = 10, this.centre});

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
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => CustomPaint(
        size: Size.square(taille),
        painter: _AnneauPainter(segments, t, epaisseur, context.lab.border),
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
  _AnneauPainter(this.segments, this.progression, this.epaisseur, this.fond);

  final List<(double, Color)> segments;
  final double progression;
  final double epaisseur;
  final Color fond;

  @override
  void paint(Canvas canvas, Size size) {
    final zone = (Offset.zero & size).deflate(epaisseur / 2);
    canvas.drawArc(
      zone,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..color = fond,
    );

    final total = segments.fold<double>(0, (a, s) => a + s.$1);
    if (total == 0) return;
    const ecart = .06;
    var depart = -math.pi / 2;
    for (final (valeur, couleur) in segments) {
      final balayage = 2 * math.pi * valeur / total;
      final visible = math.max(0.0, (balayage - (segments.length > 1 ? ecart : 0)) * progression);
      canvas.drawArc(
        zone,
        depart + ecart / 2,
        visible,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = epaisseur
          ..strokeCap = StrokeCap.butt
          ..color = couleur,
      );
      depart += balayage;
    }
  }

  @override
  bool shouldRepaint(_AnneauPainter old) => old.progression != progression || old.segments != segments || old.fond != fond;
}
