import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/aurora.dart';
import '../../core/widgets/composants.dart';
import '../auth/auth_controller.dart';
import '../equipements/equipements_repository.dart';
import '../equipements/widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _rafraichir(WidgetRef ref) async {
    ref.invalidate(statistiquesProvider);
    ref.invalidate(recentsProvider);
    ref.invalidate(laboratoiresProvider);
    await ref.read(statistiquesProvider(null).future).catchError((_) => const Statistiques(total: 0, parStatut: {}));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(utilisateurProvider);
    final stats = ref.watch(statistiquesProvider(null));
    final recents = ref.watch(recentsProvider);
    final labos = ref.watch(laboratoiresProvider);

    return Scaffold(
      body: AuroraBackground(
        intensite: .55,
        child: RefreshIndicator(
          onRefresh: () => _rafraichir(ref),
          edgeOffset: MediaQuery.paddingOf(context).top,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Entree(child: _EnTete(utilisateur: utilisateur)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Entree(
                    index: 1,
                    child: stats.when(
                      data: (s) => _CarteHeros(stats: s),
                      loading: () => const Skeleton(height: 228, radius: 32),
                      error: (e, _) => SurfaceCard(
                        child: EtatVide(
                          icone: Icons.cloud_off_rounded,
                          titre: 'Impossible de joindre le serveur',
                          message: messageErreur(e),
                          action: 'Réessayer',
                          couleur: Palette.rose,
                          onAction: () => ref.invalidate(statistiquesProvider),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (stats.hasValue)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.38,
                    children: [
                      for (final (i, s) in statuts.entries.indexed)
                        Entree(
                          index: 2 + i,
                          child: _TuileStatut(cle: s.key, apparence: s.value, valeur: stats.value![s.key]),
                        ),
                    ],
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: TitreSection('Laboratoires', action: 'Tout voir', onAction: () => context.go('/laboratoires')),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 132,
                  child: labos.when(
                    data: (liste) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: liste.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => Entree(index: i, decalage: const Offset(30, 0), child: _CarteLaboMini(liste[i])),
                    ),
                    loading: () => ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        Skeleton(width: 200, height: 132, radius: 26),
                        SizedBox(width: 12),
                        Skeleton(width: 200, height: 132, radius: 26),
                      ],
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: TitreSection('Ajoutés récemment', action: 'Inventaire', onAction: () => context.go('/equipements')),
                ),
              ),
              recents.when(
                data: (liste) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => Entree(index: i, child: EquipementTile(liste[i])),
                  ),
                ),
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, _) => const EquipementTileSkeleton(),
                  ),
                ),
                error: (_, _) => const SliverToBoxAdapter(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({required this.utilisateur});
  final Utilisateur? utilisateur;

  @override
  Widget build(BuildContext context) {
    final u = utilisateur;
    return Row(
      children: [
        Pressable(
          onTap: () => context.go('/profil'),
          child: Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.signature),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.lab.surface),
              alignment: Alignment.center,
              child: GradientText(u?.initiales ?? '?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${salutation()},', style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted)),
              Text(
                u?.prenom.isNotEmpty == true ? u!.prenom : (u?.nomComplet ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
            ],
          ),
        ),
        if (u != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.or.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: context.or.withValues(alpha: .35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 15, color: context.or),
                const SizedBox(width: 6),
                Text(
                  u.roleLibelle.split(' ').first,
                  style: TextStyle(color: context.or, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CarteHeros extends StatelessWidget {
  const _CarteHeros({required this.stats});
  final Statistiques stats;

  @override
  Widget build(BuildContext context) {
    final dispo = stats['disponible'];
    final taux = stats.total == 0 ? 0 : (dispo * 100 / stats.total).round();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: Palette.signatureSoft,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Palette.iris.withValues(alpha: .45), blurRadius: 40, offset: const Offset(0, 18), spreadRadius: -14),
        ],
      ),
      child: Stack(
        children: [
          // Décor : grands cercles translucides
          Positioned(right: -60, top: -70, child: _Cercle(220, .12)),
          Positioned(left: -40, bottom: -90, child: _Cercle(200, .08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PARC D\'ÉQUIPEMENTS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CompteurAnime(
                            stats.total,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$dispo disponibles · $taux % du parc',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .85),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnneauStatuts(
                      stats: stats,
                      taille: 104,
                      epaisseur: 11,
                      centre: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$taux%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ),
                          Text(
                            'dispo.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Pressable(
                  onTap: () => context.push('/scanner'),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: .3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Scanner un équipement',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cercle extends StatelessWidget {
  const _Cercle(this.taille, this.opacite);
  final double taille;
  final double opacite;

  @override
  Widget build(BuildContext context) => Container(
    width: taille,
    height: taille,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: opacite), width: 26),
    ),
  );
}

class _TuileStatut extends StatelessWidget {
  const _TuileStatut({required this.cle, required this.apparence, required this.valeur});

  final String cle;
  final Apparence apparence;
  final int valeur;

  @override
  Widget build(BuildContext context) {
    final c = apparence.couleur;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.go('/equipements?statut=$cle'),
      child: Stack(
        children: [
          Positioned(right: -6, top: -6, child: Icon(apparence.icone, size: 56, color: c.withValues(alpha: .08))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(11)),
                child: Icon(apparence.icone, color: c, size: 19),
              ),
              const Spacer(),
              CompteurAnime(valeur, style: context.text.headlineMedium?.copyWith(height: 1)),
              const SizedBox(height: 2),
              Text((n) {
                final l = libelleStatutCompte(cle, n);
                return l[0].toUpperCase() + l.substring(1);
              }(valeur), style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteLaboMini extends StatelessWidget {
  const _CarteLaboMini(this.labo);
  final Laboratoire labo;

  @override
  Widget build(BuildContext context) {
    final teintes = teintesLaboratoire(labo.code);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 26,
      onTap: () => context.push('/laboratoire/${labo.id}', extra: labo.nom),
      child: SizedBox(
        width: 168,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GradientIcon(icone: Icons.science_rounded, teintes: teintes, taille: 38, rayon: 12),
                const Spacer(),
                Text(labo.code, style: styleCode.copyWith(color: teintes.first, fontSize: 11.5)),
              ],
            ),
            const Spacer(),
            Text(
              labo.nom,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text('${labo.nbEquipements} équipements', style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
