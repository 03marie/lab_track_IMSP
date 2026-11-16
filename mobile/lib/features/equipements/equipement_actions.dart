import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/dialogues.dart';
import 'equipements_repository.dart';

/// Ce qui s'est passé après « Supprimer » : l'écran appelant s'adapte (fermer la fiche, etc.).
enum IssueSuppression { supprime, retire, aucune }

/// Supprime un équipement. Règle de traçabilité : suppression définitive seulement s'il n'a jamais servi ;
/// sinon le serveur refuse (409) et on propose de le « retirer du parc » (historique conservé).
Future<IssueSuppression> supprimerEquipementFlow(BuildContext context, WidgetRef ref, Equipement e) async {
  final ok = await confirmer(
    context,
    icone: Icons.delete_forever_rounded,
    couleur: Palette.rose,
    titre: 'Supprimer cet équipement ?',
    message:
        '« ${e.nom} » (${e.code}) sera supprimé définitivement.\n'
        'Possible seulement s\'il n\'a jamais été utilisé ; sinon il sera proposé au retrait.',
    action: 'Supprimer',
  );
  if (ok != true || !context.mounted) return IssueSuppression.aucune;

  try {
    await ref.read(equipementsRepositoryProvider).supprimerEquipement(e.id);
    rafraichirDonnees(ref);
    if (context.mounted) notifier(context, '${e.nom} supprimé');
    return IssueSuppression.supprime;
  } on DioException catch (err) {
    if (!context.mounted) return IssueSuppression.aucune;
    if (err.response?.statusCode == 409) {
      return retirerEquipementFlow(context, ref, e, intro: messageErreur(err));
    }
    notifier(context, messageErreur(err), erreur: true);
    return IssueSuppression.aucune;
  }
}

/// Retire un équipement du parc (motif obligatoire). Il disparaît des listes, son historique reste.
Future<IssueSuppression> retirerEquipementFlow(BuildContext context, WidgetRef ref, Equipement e, {String? intro}) async {
  final motif = await saisirTexte(
    context,
    icone: Icons.archive_rounded,
    couleur: Palette.amber,
    titre: 'Retirer du parc ?',
    message: '${intro ?? '« ${e.nom} » disparaîtra des listes.'}\nSon historique reste consultable.',
    libelle: 'Motif du retrait (ex. réformé, perdu, cassé)',
    action: 'Retirer',
  );
  if (motif == null || !context.mounted) return IssueSuppression.aucune;

  try {
    await ref.read(equipementsRepositoryProvider).retirer(e.id, motif);
    rafraichirDonnees(ref);
    if (context.mounted) notifier(context, '${e.nom} retiré du parc');
    return IssueSuppression.retire;
  } on DioException catch (err) {
    if (context.mounted) notifier(context, messageErreur(err), erreur: true);
    return IssueSuppression.aucune;
  }
}
