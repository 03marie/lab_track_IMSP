import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import 'equipements_repository.dart';
import 'widgets.dart';

class DetailEquipementScreen extends ConsumerWidget {
  const DetailEquipementScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipement = ref.watch(equipementProvider(id));
    return Scaffold(
      body: equipement.when(
        data: (e) => _Contenu(e),
        loading: () => _Chargement(id: id),
        error: (err, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _BoutonVerre(icone: Icons.arrow_back_rounded, onTap: () => context.pop()),
                ),
              ),
              Expanded(
                child: Center(
                  child: EtatVide(
                    icone: Icons.cloud_off_rounded,
                    titre: 'Fiche indisponible',
                    message: messageErreur(err),
                    action: 'Réessayer',
                    couleur: Palette.rose,
                    onAction: () => ref.invalidate(equipementProvider(id)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu(this.e);
  final Equipement e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuel = visuelCategorie(e.categorieNom);
    final historique = ref.watch(historiqueProvider(e.id));
    final haut = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(equipementProvider(e.id));
        ref.invalidate(historiqueProvider(e.id));
      },
      edgeOffset: haut + 60,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 330,
            backgroundColor: visuel.teintes.first,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: _BoutonVerre(icone: Icons.arrow_back_rounded, onTap: () => context.pop()),
              ),
            ),
            leadingWidth: 62,
            actions: [
              _BoutonVerre(icone: Icons.view_week_rounded, onTap: () => _afficherCodeBarres(context, e)),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
              background: _EnTeteImmersif(e: e, teintes: visuel.teintes, icone: visuel.icone),
            ),
          ),
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entree(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [StatusPill.statut(e.statut), StatusPill(apparenceEtat(e.etat))],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Entree(index: 1, child: _ActionsRapides(e: e)),
                    const SizedBox(height: 26),
                    const Entree(index: 2, child: TitreSection('Informations')),
                    const SizedBox(height: 12),
                    Entree(index: 3, child: _CarteInfos(e: e)),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      const TitreSection('Description'),
                      const SizedBox(height: 12),
                      SurfaceCard(child: Text(e.description, style: context.text.bodyMedium)),
                    ],
                    const SizedBox(height: 26),
                    const Entree(index: 4, child: TitreSection('Historique')),
                    const SizedBox(height: 14),
                    historique.when(
                      data: (liste) => liste.isEmpty
                          ? Text('Aucun mouvement enregistré.', style: context.text.bodySmall)
                          : _Chronologie(liste),
                      loading: () => const Column(
                        children: [Skeleton(height: 64, radius: 18), SizedBox(height: 10), Skeleton(height: 64, radius: 18)],
                      ),
                      error: (err, _) => Text(messageErreur(err), style: const TextStyle(color: Palette.rose)),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnTeteImmersif extends StatelessWidget {
  const _EnTeteImmersif({required this.e, required this.teintes, required this.icone});

  final Equipement e;
  final List<Color> teintes;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (e.photo != null)
          Image.network(e.photo!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [teintes.first, teintes.last, Palette.ink900],
              ),
            ),
          ),
        // Motif de cercles concentriques
        Positioned(right: -80, top: -40, child: _Anneaux(couleur: Colors.white.withValues(alpha: .1))),
        // Voile pour la lisibilité du texte
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x00000000), Color(0x99000000)],
              stops: [0, .4, 1],
            ),
          ),
        ),
        // Bord arrondi de la feuille de contenu, dessiné dans l'en-tête (toujours visible au-dessus).
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: context.lab.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'equipement-${e.id}',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: .35)),
                  ),
                  child: Icon(icone, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                e.nom,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e.code, style: styleCode.copyWith(color: Colors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.categorieNom,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Anneaux extends StatelessWidget {
  const _Anneaux({required this.couleur});
  final Color couleur;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 300,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final t in [300.0, 220.0, 140.0])
          Container(
            width: t,
            height: t,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: couleur, width: 1.5),
            ),
          ),
      ],
    ),
  );
}

class _ActionsRapides extends StatelessWidget {
  const _ActionsRapides({required this.e});
  final Equipement e;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Action(
            icone: Icons.view_week_rounded,
            libelle: 'Code-barres',
            couleur: Palette.violet,
            onTap: () => _afficherCodeBarres(context, e),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icone: Icons.copy_rounded,
            libelle: 'Copier le code',
            couleur: Palette.aqua,
            onTap: () {
              Clipboard.setData(ClipboardData(text: e.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('${e.code} copié')));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icone: Icons.qr_code_scanner_rounded,
            libelle: 'Scanner',
            couleur: Palette.gold,
            onTap: () => context.push('/scanner'),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icone, required this.libelle, required this.couleur, required this.onTap});

  final IconData icone;
  final String libelle;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    radius: 22,
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: couleur.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
          child: Icon(icone, color: couleur, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CarteInfos extends StatelessWidget {
  const _CarteInfos({required this.e});
  final Equipement e;

  @override
  Widget build(BuildContext context) {
    final lignes = <(IconData, String, String)>[
      (Icons.science_rounded, 'Laboratoire', e.laboratoireNom),
      (Icons.place_rounded, 'Emplacement', e.emplacement),
      (Icons.category_rounded, 'Catégorie', e.categorieNom),
      (Icons.sell_rounded, 'Marque · modèle', e.marqueModele),
      (Icons.numbers_rounded, 'N° de série', e.numeroSerie),
      (Icons.event_rounded, 'Acquisition', e.dateAcquisition == null ? '' : formatDate(e.dateAcquisition)),
      (Icons.add_task_rounded, 'Enregistré le', e.creeLe == null ? '' : formatDate(e.creeLe)),
    ].where((l) => l.$3.isNotEmpty).toList();

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (final (i, (icone, libelle, valeur)) in lignes.indexed) ...[
            if (i > 0) Divider(color: context.lab.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Icon(icone, size: 20, color: context.lab.textMuted),
                  const SizedBox(width: 14),
                  Text(libelle, style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      valeur,
                      textAlign: TextAlign.right,
                      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chronologie extends StatelessWidget {
  const _Chronologie(this.mouvements);
  final List<Mouvement> mouvements;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Column(
      children: [
        for (final (i, m) in mouvements.indexed)
          Entree(
            index: i,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: apparenceMouvement(m.type).couleur,
                            border: Border.all(color: lab.background, width: 3),
                            boxShadow: [
                              BoxShadow(color: apparenceMouvement(m.type).couleur.withValues(alpha: .6), blurRadius: 10),
                            ],
                          ),
                        ),
                        if (i < mouvements.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [apparenceMouvement(m.type).couleur.withValues(alpha: .5), lab.border],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(apparenceMouvement(m.type).icone, size: 16, color: apparenceMouvement(m.type).couleur),
                              const SizedBox(width: 6),
                              Text(
                                apparenceMouvement(m.type).libelle,
                                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(formatRelatif(m.date), style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
                            ],
                          ),
                          if (m.details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(m.details, style: context.text.bodyMedium?.copyWith(color: lab.textMuted, fontSize: 13.5)),
                          ],
                          if (m.auteur.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 14, color: lab.textMuted),
                                const SizedBox(width: 4),
                                Text(m.auteur, style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Chargement extends StatelessWidget {
  const _Chargement({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      const Skeleton(height: 330, radius: 0),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Row(
              children: [
                Skeleton(width: 110, height: 30, radius: 99),
                SizedBox(width: 8),
                Skeleton(width: 100, height: 30, radius: 99),
              ],
            ),
            SizedBox(height: 18),
            Skeleton(height: 100, radius: 22),
            SizedBox(height: 26),
            Skeleton(height: 260, radius: 24),
          ],
        ),
      ),
    ],
  );
}

class _BoutonVerre extends StatelessWidget {
  const _BoutonVerre({required this.icone, required this.onTap});
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      child: Icon(icone, color: Colors.white, size: 22),
    ),
  );
}

/// Feuille affichant le code-barres de l'équipement (pour vérifier ou rescanner une étiquette).
void _afficherCodeBarres(BuildContext context, Equipement e) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final image = ref.watch(codeBarresProvider(e.id));
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Étiquette', style: context.text.titleLarge),
              const SizedBox(height: 4),
              Text(e.nom, style: context.text.bodySmall),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                height: 170,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.iris.withValues(alpha: .25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: image.when(
                  data: (octets) => Image.memory(octets, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      messageErreur(err),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Palette.rose),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Code 128 · ${e.code}', style: styleCode.copyWith(color: context.lab.textMuted)),
            ],
          ),
        );
      },
    ),
  );
}
