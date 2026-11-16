import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/dialogues.dart';
import '../equipements/equipements_repository.dart';
import '../../core/widgets/feuille.dart';

/// Supprime un laboratoire (administrateur). Refusé par le serveur s'il contient encore des équipements.
Future<bool> supprimerLaboFlow(BuildContext context, WidgetRef ref, {required int id, required String nom}) async {
  final ok = await confirmer(
    context,
    icone: Icons.delete_forever_rounded,
    couleur: Palette.rose,
    titre: 'Supprimer ce laboratoire ?',
    message: '« $nom » sera supprimé définitivement.\nImpossible tant qu\'il contient des équipements.',
    action: 'Supprimer',
  );
  if (ok != true || !context.mounted) return false;

  try {
    await ref.read(equipementsRepositoryProvider).supprimerLaboratoire(id);
    rafraichirDonnees(ref);
    if (context.mounted) notifier(context, 'Laboratoire « $nom » supprimé');
    return true;
  } on DioException catch (err) {
    if (!context.mounted) return false;
    if (err.response?.statusCode == 409) {
      await informer(context, titre: 'Suppression impossible', message: messageErreur(err), icone: Icons.inventory_2_rounded);
    } else {
      notifier(context, messageErreur(err), erreur: true);
    }
    return false;
  }
}

/// Feuille de création d'un laboratoire.
Future<void> ouvrirFormulaireLabo(BuildContext context) =>
    ouvrirFeuille<void>(context: context, isScrollControlled: true, builder: (_) => const _FormulaireLabo());

class _FormulaireLabo extends ConsumerStatefulWidget {
  const _FormulaireLabo();

  @override
  ConsumerState<_FormulaireLabo> createState() => _FormulaireLaboState();
}

class _FormulaireLaboState extends ConsumerState<_FormulaireLabo> {
  final _cle = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _nom = TextEditingController();
  final _localisation = TextEditingController();
  final _responsables = <int>{};
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _code.dispose();
    _nom.dispose();
    _localisation.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final labo = await ref
          .read(equipementsRepositoryProvider)
          .creerLaboratoire(
            code: _code.text.trim().toUpperCase(),
            nom: _nom.text.trim(),
            localisation: _localisation.text.trim(),
            responsables: _responsables.toList(),
          );
      rafraichirDonnees(ref);
      if (!mounted) return;
      Navigator.pop(context);
      notifier(context, 'Laboratoire « ${labo.nom} » créé');
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsables = ref.watch(responsablesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
      child: SingleChildScrollView(
        child: Form(
          key: _cle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconeTuile(icone: Icons.science_rounded, couleur: Palette.accent, taille: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nouveau laboratoire', style: context.text.titleLarge),
                        Text('Il apparaîtra tout de suite dans l\'application', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Donnez un nom au laboratoire' : null,
                decoration: const InputDecoration(
                  labelText: 'Nom du laboratoire *',
                  hintText: 'Laboratoire de chimie',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                maxLength: 20,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Saisissez un code court (ex. CHIM)' : null,
                decoration: const InputDecoration(
                  labelText: 'Code court *',
                  hintText: 'CHIM',
                  counterText: '',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localisation,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Localisation',
                  hintText: 'Bâtiment C, salle 4',
                  prefixIcon: Icon(Icons.place_rounded),
                ),
              ),
              const SizedBox(height: 18),
              Text('Responsables', style: context.text.labelLarge?.copyWith(color: context.lab.textMuted)),
              const SizedBox(height: 8),
              responsables.when(
                data: (liste) => liste.isEmpty
                    ? Text(
                        'Aucun compte « responsable » pour l\'instant. Vous pourrez en ajouter plus tard.',
                        style: context.text.bodySmall,
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final u in liste)
                            FilterChip(
                              label: Text(u.nomComplet),
                              selected: _responsables.contains(u.id),
                              showCheckmark: false,
                              avatar: Icon(
                                _responsables.contains(u.id) ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                                size: 18,
                              ),
                              onSelected: (v) => setState(() => v ? _responsables.add(u.id) : _responsables.remove(u.id)),
                            ),
                        ],
                      ),
                loading: () => const Skeleton(height: 36, radius: 12),
                error: (_, _) => Text('Liste des responsables indisponible.', style: context.text.bodySmall),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _erreur == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _erreur!,
                          style: const TextStyle(color: Palette.rose, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              BoutonPrincipal(
                label: 'Créer le laboratoire',
                icone: Icons.add_rounded,
                chargement: _chargement,
                onPressed: _creer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
