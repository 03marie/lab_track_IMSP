import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import '../equipements/equipements_repository.dart';

/// Carte de laboratoire : une couleur propre à chaque laboratoire (filet et icône), le reste est sobre.
/// `compact` : version réduite pour les listes horizontales (sans le compteur de disponibles).
class LaboCard extends ConsumerWidget {
  const LaboCard(this.labo, {super.key, this.compact = false});

  final Laboratoire labo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = couleurLabo(labo.code);
    final stats = compact ? null : ref.watch(statistiquesProvider(labo.id)).value;
    final dispo = stats?['disponible'];

    return SurfaceCard(
      accent: couleur,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () => context.push('/laboratoire/${labo.id}', extra: labo.nom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconeTuile(icone: Icons.science_rounded, couleur: couleur, taille: 40),
              const Spacer(),
              Text(
                labo.code,
                style: TextStyle(color: context.lab.textMuted, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: .8),
              ),
            ],
          ),
          const Spacer(),
          Text(
            nomCourtLabo(labo.nom),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(height: 1.15),
          ),
          const SizedBox(height: 3),
          Text(
            '${labo.nbEquipements} équipement${labo.nbEquipements > 1 ? 's' : ''}',
            style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (dispo != null && stats!.total > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Palette.emerald, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$dispo disponible${dispo > 1 ? 's' : ''}',
                  style: TextStyle(color: context.lisible(Palette.emerald), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
