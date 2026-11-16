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
import '../auth/auth_controller.dart';
import 'equipement_actions.dart';
import 'equipements_repository.dart';
import 'widgets.dart';
import '../../core/widgets/feuille.dart';

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
                  child: _BoutonCarre(icone: Icons.arrow_back_rounded, onTap: () => context.pop()),
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
            backgroundColor: context.lab.background,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: _BoutonCarre(icone: Icons.arrow_back_rounded, onTap: () => context.pop()),
              ),
            ),
            actions: [
              if (ref.watch(utilisateurProvider)?.peutGererLabo(e.laboratoireId) ?? false)
                _MenuEquipement(e: e)
              else
                _BoutonCarre(icone: Icons.view_week_rounded, onTap: () => _afficherCodeBarres(context, e)),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Entree(
                child: _EnTeteFiche(e: e, couleur: visuel.couleur, icone: visuel.icone),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
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
                    if (e.statut == 'retire') ...[Entree(index: 1, child: _BandeauRetire()), const SizedBox(height: 14)],
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

/// En-tête de la fiche : photo (si elle existe), icône de catégorie, nom, code et catégorie.
class _EnTeteFiche extends StatelessWidget {
  const _EnTeteFiche({required this.e, required this.couleur, required this.icone});

  final Equipement e;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.photo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                e.photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: lab.surfaceHigh),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'equipement-${e.id}',
              child: IconeTuile(icone: icone, couleur: couleur, taille: 52, rayon: 14),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nom, style: context.text.headlineSmall?.copyWith(height: 1.15)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(e.code, style: styleCode.copyWith(color: lab.accent, fontSize: 13)),
                      Text(e.categorieNom, style: context.text.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
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
            couleur: context.accent,
            onTap: () => _afficherCodeBarres(context, e),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icone: Icons.picture_as_pdf_rounded,
            libelle: 'Étiquette A4',
            couleur: Palette.ochre,
            onTap: () => context.push('/etiquettes?ids=${e.id}'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icone: Icons.copy_rounded,
            libelle: 'Copier le code',
            couleur: Palette.teal,
            onTap: () {
              Clipboard.setData(ClipboardData(text: e.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('${e.code} copié')));
            },
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
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    onTap: onTap,
    child: Column(
      children: [
        IconeTuile(icone: icone, couleur: couleur, taille: 42),
        const SizedBox(height: 10),
        Text(
          libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
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
                          ),
                        ),
                        if (i < mouvements.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(color: lab.border),
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
      const SizedBox(height: 120),
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
            Skeleton(height: 100, radius: 16),
            SizedBox(height: 26),
            Skeleton(height: 260, radius: 16),
          ],
        ),
      ),
    ],
  );
}

class _BoutonCarre extends StatelessWidget {
  const _BoutonCarre({required this.icone, required this.onTap});
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.lab.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.lab.border),
      ),
      child: Icon(icone, color: context.lab.text, size: 22),
    ),
  );
}

/// Feuille affichant le code-barres de l'équipement (pour vérifier ou rescanner une étiquette).
void _afficherCodeBarres(BuildContext context, Equipement e) {
  ouvrirFeuille<void>(
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.lab.border),
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

/// Bandeau affiché sur la fiche d'un équipement retiré du parc.
class _BandeauRetire extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SurfaceCard(
    accent: Palette.amber,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        const Icon(Icons.archive_rounded, color: Palette.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Cet équipement est retiré du parc : il n\'apparaît plus dans les listes mais son historique est conservé.',
            style: context.text.bodyMedium?.copyWith(height: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// Menu « ⋮ » de la fiche : modifier, retirer du parc, supprimer. Réservé à ceux qui gèrent le laboratoire.
class _MenuEquipement extends ConsumerWidget {
  const _MenuEquipement({required this.e});
  final Equipement e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      color: context.lab.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (action) async {
        switch (action) {
          case 'modifier':
            context.push('/equipement/${e.id}/modifier', extra: e);
          case 'retirer':
            await retirerEquipementFlow(context, ref, e);
          case 'supprimer':
            final issue = await supprimerEquipementFlow(context, ref, e);
            if (issue == IssueSuppression.supprime && context.mounted) context.pop();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'modifier',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, color: context.accent),
              SizedBox(width: 12),
              Text('Modifier'),
            ],
          ),
        ),
        if (e.statut != 'retire')
          const PopupMenuItem(
            value: 'retirer',
            child: Row(
              children: [
                Icon(Icons.archive_rounded, color: Palette.amber),
                SizedBox(width: 12),
                Text('Retirer du parc'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'supprimer',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Palette.rose),
              SizedBox(width: 12),
              Text('Supprimer'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.lab.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.lab.border),
        ),
        child: Icon(Icons.more_vert_rounded, color: context.lab.text, size: 22),
      ),
    );
  }
}
