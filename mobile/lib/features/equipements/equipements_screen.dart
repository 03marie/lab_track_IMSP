import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import '../auth/auth_controller.dart';
import '../laboratoires/labo_actions.dart';
import 'equipements_repository.dart';
import 'widgets.dart';

/// Liste des équipements. Sert aussi pour un laboratoire précis (`laboratoire` + `titre`).
class EquipementsScreen extends ConsumerStatefulWidget {
  const EquipementsScreen({super.key, this.statutInitial, this.laboratoire, this.titre});

  final String? statutInitial;
  final int? laboratoire;
  final String? titre;

  @override
  ConsumerState<EquipementsScreen> createState() => _EquipementsScreenState();
}

class _EquipementsScreenState extends ConsumerState<EquipementsScreen> {
  final _recherche = TextEditingController();
  Timer? _attente;
  bool _grille = true; // grille de petites cartes colorées (sinon liste)
  late FiltreEquipements _filtre = (recherche: '', statut: widget.statutInitial, laboratoire: widget.laboratoire, tri: 'code');

  @override
  void didUpdateWidget(EquipementsScreen ancien) {
    super.didUpdateWidget(ancien);
    // Arrivée depuis une tuile du tableau de bord (ex. /equipements?statut=emprunte).
    if (widget.statutInitial != ancien.statutInitial) {
      setState(
        () => _filtre = (
          recherche: _filtre.recherche,
          statut: widget.statutInitial,
          laboratoire: _filtre.laboratoire,
          tri: _filtre.tri,
        ),
      );
    }
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _rechercher(String texte) {
    // « Debounce » : on attend que l'utilisateur arrête de taper avant d'interroger le serveur.
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 350), () {
      setState(
        () => _filtre = (recherche: texte.trim(), statut: _filtre.statut, laboratoire: _filtre.laboratoire, tri: _filtre.tri),
      );
    });
  }

  void _choisirStatut(String? statut) {
    HapticFeedback.selectionClick();
    setState(() => _filtre = (recherche: _filtre.recherche, statut: statut, laboratoire: _filtre.laboratoire, tri: _filtre.tri));
  }

  /// Boutons à droite du titre : affichage grille/liste, ajout d'équipement, menu du laboratoire.
  List<Widget> _actionsEntete() {
    final u = ref.watch(utilisateurProvider);
    final labo = widget.laboratoire;
    final peutAjouter = u != null && (labo == null ? u.peutGerer : u.peutGererLabo(labo));
    return [
      const SizedBox(width: 10),
      _BoutonRond(
        icone: _grille ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
        onTap: () => setState(() => _grille = !_grille),
      ),
      if (peutAjouter) ...[
        const SizedBox(width: 10),
        Pressable(
          onTap: () => context.push(labo == null ? '/equipement/nouveau' : '/equipement/nouveau?labo=$labo'),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
      if (labo != null) ...[
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Plus d\'actions',
          color: context.lab.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onSelected: (v) async {
            if (v == 'etiquettes') {
              context.push('/etiquettes?labo=$labo&titre=${Uri.encodeComponent(widget.titre ?? 'Laboratoire')}');
            } else if (v == 'supprimer') {
              final fait = await supprimerLaboFlow(context, ref, id: labo, nom: widget.titre ?? 'ce laboratoire');
              if (fait && mounted) context.pop();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'etiquettes',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded, color: context.accent),
                  SizedBox(width: 12),
                  Text('Imprimer les étiquettes'),
                ],
              ),
            ),
            if (u?.estAdmin ?? false)
              const PopupMenuItem(
                value: 'supprimer',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Palette.rose),
                    SizedBox(width: 12),
                    Text('Supprimer le laboratoire'),
                  ],
                ),
              ),
          ],
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.lab.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.lab.border),
            ),
            child: Icon(Icons.more_vert_rounded, color: context.lab.text),
          ),
        ),
      ],
    ];
  }

  Future<void> _rafraichir() async {
    ref.invalidate(pageEquipementsProvider);
    try {
      await ref.read(pageEquipementsProvider((_filtre, 1)).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final premiere = ref.watch(pageEquipementsProvider((_filtre, 1)));
    final total = premiere.value?.total;
    final pourUnLabo = widget.laboratoire != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      if (pourUnLabo) ...[
                        _BoutonRond(icone: Icons.arrow_back_rounded, onTap: () => context.pop()),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titre ?? 'Équipements',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: pourUnLabo ? context.text.headlineSmall : context.text.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                total == null ? 'Chargement…' : '$total équipement${total > 1 ? 's' : ''}',
                                key: ValueKey(total),
                                style: context.text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._actionsEntete(),
                    ],
                  ),
                ),
              ),
            ),
            // Barre de recherche (reste visible en haut pendant le défilement)
            SliverPersistentHeader(
              pinned: true,
              delegate: _EnTeteFixe(
                hauteur: 128,
                child: Container(
                  color: lab.background,
                  padding: const EdgeInsets.fromLTRB(20, 14, 0, 10),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: TextField(
                          controller: _recherche,
                          onChanged: (v) {
                            setState(() {}); // affiche/masque la croix
                            _rechercher(v);
                          },
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Nom, code, marque, n° de série…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: _recherche.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _recherche.clear();
                                      _rechercher('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _Filtre(
                              libelle: 'Tous',
                              couleur: context.accent,
                              actif: _filtre.statut == null,
                              onTap: () => _choisirStatut(null),
                            ),
                            for (final s in statuts.entries)
                              _Filtre(
                                libelle: s.value.libelle,
                                couleur: s.value.couleur,
                                actif: _filtre.statut == s.key,
                                onTap: () => _choisirStatut(s.key),
                              ),
                            const SizedBox(width: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...premiere.when(
              data: (page) => page.total == 0
                  ? [
                      SliverSafeArea(
                        top: false,
                        sliver: SliverFillRemaining(
                          hasScrollBody: false,
                          child: EtatVide(
                            icone: Icons.search_off_rounded,
                            titre: 'Aucun équipement',
                            message: _filtre.recherche.isNotEmpty || _filtre.statut != null
                                ? 'Aucun résultat pour ces critères.'
                                : 'Les équipements enregistrés apparaîtront ici.',
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                        sliver: _grille
                            ? SliverGrid.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: .92,
                                ),
                                itemCount: page.total,
                                itemBuilder: (context, i) => _Ligne(filtre: _filtre, index: i, grille: true),
                              )
                            : SliverList.separated(
                                itemCount: page.total,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, i) => _Ligne(filtre: _filtre, index: i, grille: false),
                              ),
                      ),
                    ],
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  sliver: _grille
                      ? SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: .92,
                          ),
                          itemCount: 6,
                          itemBuilder: (_, _) => const EquipementCardSkeleton(),
                        )
                      : SliverList.separated(
                          itemCount: 6,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, _) => const EquipementTileSkeleton(),
                        ),
                ),
              ],
              error: (e, _) => [
                SliverSafeArea(
                  top: false,
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: EtatVide(
                      icone: Icons.cloud_off_rounded,
                      titre: 'Chargement impossible',
                      message: messageErreur(e),
                      action: 'Réessayer',
                      couleur: Palette.rose,
                      onAction: _rafraichir,
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}

/// Une ligne : charge (et met en cache) la page qui la contient.
class _Ligne extends ConsumerWidget {
  const _Ligne({required this.filtre, required this.index, required this.grille});

  final FiltreEquipements filtre;
  final int index;
  final bool grille;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(pageEquipementsProvider((filtre, index ~/ taillePage + 1)));
    return page.when(
      data: (p) {
        final i = index % taillePage;
        if (i >= p.elements.length) return const SizedBox.shrink();
        final tuile = grille ? EquipementCard(p.elements[i]) : EquipementTile(p.elements[i]);
        return index < 12 ? Entree(index: index ~/ (grille ? 2 : 1), child: tuile) : tuile;
      },
      loading: () => grille ? const EquipementCardSkeleton() : const EquipementTileSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({required this.libelle, required this.couleur, required this.actif, required this.onTap});

  final String libelle;
  final Color couleur;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        haptique: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: actif ? couleur.withValues(alpha: .16) : lab.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: actif ? couleur.withValues(alpha: .55) : lab.border, width: actif ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: actif ? 8 : 6,
                height: actif ? 8 : 6,
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                libelle,
                style: TextStyle(
                  color: actif ? couleur : lab.textMuted,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({required this.icone, required this.onTap});
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: context.lab.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.lab.border),
      ),
      child: Icon(icone, color: context.lab.text),
    ),
  );
}

class _EnTeteFixe extends SliverPersistentHeaderDelegate {
  _EnTeteFixe({required this.hauteur, required this.child});
  final double hauteur;
  final Widget child;

  @override
  double get minExtent => hauteur;
  @override
  double get maxExtent => hauteur;

  @override
  Widget build(BuildContext context, double decalage, bool chevauche) => child;

  @override
  bool shouldRebuild(_EnTeteFixe old) => true;
}
