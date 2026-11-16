import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

/// Boîte de confirmation (icône colorée, deux boutons). Retourne `true` si l'utilisateur confirme.
Future<bool?> confirmer(
  BuildContext context, {
  required IconData icone,
  required Color couleur,
  required String titre,
  required String message,
  required String action,
  String annuler = 'Annuler',
}) {
  HapticFeedback.selectionClick();
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: couleur.withValues(alpha: .14), shape: BoxShape.circle),
        child: Icon(icone, color: couleur, size: 30),
      ),
      title: Text(titre, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(annuler)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: couleur, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Demande un texte obligatoire (ex. motif d'un retrait). Retourne le texte, ou `null` si annulé.
Future<String?> saisirTexte(
  BuildContext context, {
  required IconData icone,
  required Color couleur,
  required String titre,
  required String message,
  required String libelle,
  required String action,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _DialogueSaisie(icone: icone, couleur: couleur, titre: titre, message: message, libelle: libelle, action: action),
  );
}

class _DialogueSaisie extends StatefulWidget {
  const _DialogueSaisie({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.message,
    required this.libelle,
    required this.action,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String message;
  final String libelle;
  final String action;

  @override
  State<_DialogueSaisie> createState() => _DialogueSaisieState();
}

class _DialogueSaisieState extends State<_DialogueSaisie> {
  final _champ = TextEditingController();
  bool _vide = false;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _valider() {
    final texte = _champ.text.trim();
    if (texte.isEmpty) {
      setState(() => _vide = true);
      return;
    }
    Navigator.pop(context, texte);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: widget.couleur.withValues(alpha: .14), shape: BoxShape.circle),
      child: Icon(widget.icone, color: widget.couleur, size: 30),
    ),
    title: Text(widget.titre, textAlign: TextAlign.center),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _champ,
          autofocus: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _vide ? setState(() => _vide = false) : null,
          decoration: InputDecoration(labelText: widget.libelle, errorText: _vide ? 'Ce champ est obligatoire' : null),
        ),
      ],
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: widget.couleur, foregroundColor: Colors.white),
        onPressed: _valider,
        child: Text(widget.action),
      ),
    ],
  );
}

/// Message d'information (succès) ou d'erreur, en bas de l'écran.
void notifier(BuildContext context, String message, {bool erreur = false}) {
  if (!context.mounted) return;
  if (erreur) HapticFeedback.heavyImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: erreur ? 5 : 3),
        content: Row(
          children: [
            Icon(
              erreur ? Icons.error_rounded : Icons.check_circle_rounded,
              color: erreur ? Palette.rose : Palette.emerald,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Alerte bloquante : l'action demandée est impossible (message du serveur).
Future<void> informer(
  BuildContext context, {
  required String titre,
  required String message,
  IconData icone = Icons.info_rounded,
  Color couleur = Palette.amber,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: couleur.withValues(alpha: .14), shape: BoxShape.circle),
        child: Icon(icone, color: couleur, size: 30),
      ),
      title: Text(titre, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Compris'))],
    ),
  );
}
