import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import '../equipements/equipements_repository.dart';
import '../equipements/widgets.dart';

class LaboratoiresScreen extends ConsumerWidget {
  const LaboratoiresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labos = ref.watch(laboratoiresProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(laboratoiresProvider);
          ref.invalidate(statistiquesProvider);
        },
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Laboratoires', style: context.text.headlineMedium),
                      const SizedBox(height: 2),
                      Text('Répartition du matériel par laboratoire', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
            ...labos.when(
              data: (liste) => liste.isEmpty
                  ? [
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EtatVide(
                          icone: Icons.science_outlined,
                          titre: 'Aucun laboratoire',
                          message: 'Ils se créent depuis l\'administration.',
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.separated(
                          itemCount: liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (_, i) => Entree(index: i, child: _CarteLabo(liste[i])),
                        ),
                      ),
                    ],
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, _) => const Skeleton(height: 170, radius: 28),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EtatVide(
                    icone: Icons.cloud_off_rounded,
                    titre: 'Chargement impossible',
                    message: messageErreur(e),
                    action: 'Réessayer',
                    couleur: Palette.rose,
                    onAction: () => ref.invalidate(laboratoiresProvider),
                  ),
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

class _CarteLabo extends ConsumerWidget {
  const _CarteLabo(this.labo);
  final Laboratoire labo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teintes = teintesLaboratoire(labo.code);
    final stats = ref.watch(statistiquesProvider(labo.id));
    return SurfaceCard(
      padding: EdgeInsets.zero,
      radius: 28,
      onTap: () => context.push('/laboratoire/${labo.id}', extra: labo.nom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [teintes.last.withValues(alpha: .25), teintes.last.withValues(alpha: 0)]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GradientIcon(icone: Icons.science_rounded, teintes: teintes, taille: 50),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labo.nom,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (labo.localisation.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.place_rounded, size: 14, color: context.lab.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      labo.localisation,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Text(labo.code, style: styleCode.copyWith(color: teintes.first)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${labo.nbEquipements}', style: context.text.headlineMedium?.copyWith(height: 1)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('équipements', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, color: context.lab.textMuted),
                    ],
                  ),
                  const SizedBox(height: 14),
                  stats.when(
                    data: (s) => _BarreStatuts(stats: s),
                    loading: () => const Skeleton(height: 8, radius: 99),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre segmentée + légende des statuts d'un laboratoire.
class _BarreStatuts extends StatelessWidget {
  const _BarreStatuts({required this.stats});
  final Statistiques stats;

  @override
  Widget build(BuildContext context) {
    final presents = statuts.entries.where((s) => stats[s.key] > 0).toList();
    if (stats.total == 0) return Text('Aucun équipement', style: context.text.bodySmall);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutQuart,
          builder: (context, t, _) => ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final s in presents)
                    Expanded(
                      flex: (stats[s.key] * 1000 * t).round().clamp(1, 1 << 30),
                      child: Container(margin: const EdgeInsets.only(right: 2), color: s.value.couleur),
                    ),
                  Expanded(flex: ((1 - t) * stats.total * 1000).round().clamp(0, 1 << 30), child: const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in presents)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: s.value.couleur, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${stats[s.key]} ${libelleStatutCompte(s.key, stats[s.key])}',
                    style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
