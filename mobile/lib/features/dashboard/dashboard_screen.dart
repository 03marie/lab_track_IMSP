import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/composants.dart';
import '../auth/auth_controller.dart';
import '../equipements/equipements_repository.dart';
import '../equipements/widgets.dart';
import '../laboratoires/labo_card.dart';

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
      body: RefreshIndicator(
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
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Entree(
                  index: 1,
                  child: stats.when(
                    data: (s) => _CarteResume(stats: s),
                    loading: () => const Skeleton(height: 188, radius: 16),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: TitreSection('Laboratoires', action: 'Tout voir', onAction: () => context.go('/laboratoires')),
              ),
            ),
            SliverToBoxAdapter(
              child: _RangeeHorizontale<Laboratoire>(
                valeur: labos,
                hauteur: 160,
                largeur: 176,
                vide: 'Aucun laboratoire pour l\'instant.',
                carte: (l) => LaboCard(l, compact: true),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: TitreSection('Ajoutés récemment', action: 'Tout voir', onAction: () => context.go('/equipements')),
              ),
            ),
            SliverToBoxAdapter(
              child: _RangeeHorizontale<Equipement>(
                valeur: recents,
                hauteur: 176,
                largeur: 168,
                vide: 'Aucun équipement enregistré pour l\'instant.',
                carte: EquipementCard.new,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}

/// Liste horizontale de cartes, avec états de chargement et de liste vide.
class _RangeeHorizontale<T> extends StatelessWidget {
  const _RangeeHorizontale({
    required this.valeur,
    required this.hauteur,
    required this.largeur,
    required this.vide,
    required this.carte,
  });

  final AsyncValue<List<T>> valeur;
  final double hauteur;
  final double largeur;
  final String vide;
  final Widget Function(T) carte;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      child: valeur.when(
        data: (liste) => liste.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(vide, style: context.text.bodySmall),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => Entree(
                  index: i,
                  decalage: const Offset(16, 0),
                  child: SizedBox(width: largeur, child: carte(liste[i])),
                ),
              ),
        loading: () => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Skeleton(width: largeur, height: hauteur, radius: 16),
            const SizedBox(width: 12),
            Skeleton(width: largeur, height: hauteur, radius: 16),
          ],
        ),
        error: (_, _) => const SizedBox.shrink(),
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
        Pressable(onTap: () => context.go('/profil'), child: AvatarUtilisateur(u, taille: 48)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${salutation()},', style: context.text.bodySmall),
              Text(
                u?.prenom.isNotEmpty == true ? u!.prenom : (u?.nomComplet ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
            ],
          ),
        ),
        if (u != null) Text(u.roleLibelle.split(' ').first, style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Carte de synthèse : total du parc, taux de disponibilité, répartition et accès rapide au scan.
class _CarteResume extends StatelessWidget {
  const _CarteResume({required this.stats});
  final Statistiques stats;

  @override
  Widget build(BuildContext context) {
    final dispo = stats['disponible'];
    final taux = stats.total == 0 ? 0 : (dispo * 100 / stats.total).round();
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARC D\'ÉQUIPEMENTS',
                      style: TextStyle(
                        color: context.lab.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CompteurAnime(stats.total, style: context.text.displaySmall?.copyWith(fontSize: 44, height: 1.1)),
                    const SizedBox(height: 2),
                    Text('$dispo disponible${dispo > 1 ? 's' : ''} sur ${stats.total}', style: context.text.bodySmall),
                  ],
                ),
              ),
              AnneauStatuts(
                stats: stats,
                taille: 92,
                epaisseur: 9,
                centre: Text('$taux %', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BoutonPrincipal(
            label: 'Scanner un équipement',
            icone: Icons.qr_code_scanner_rounded,
            onPressed: () => context.push('/scanner'),
          ),
        ],
      ),
    );
  }
}

class _TuileStatut extends StatelessWidget {
  const _TuileStatut({required this.cle, required this.apparence, required this.valeur});

  final String cle;
  final Apparence apparence;
  final int valeur;

  @override
  Widget build(BuildContext context) {
    final c = apparence.couleur;
    final libelle = libelleStatutCompte(cle, valeur);
    return SurfaceCard(
      accent: c,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onTap: () => context.go('/equipements?statut=$cle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(apparence.icone, color: context.lisible(c), size: 22),
          const Spacer(),
          CompteurAnime(valeur, style: context.text.headlineMedium?.copyWith(height: 1)),
          const SizedBox(height: 2),
          Text(
            libelle[0].toUpperCase() + libelle.substring(1),
            style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
