import 'package:flutter/material.dart';

import '../api/modeles.dart';
import '../theme/palette.dart';

/// Pastille ronde d'un utilisateur : sa photo de profil si elle existe, sinon ses initiales
/// sur un fond teinté.
class AvatarUtilisateur extends StatelessWidget {
  const AvatarUtilisateur(this.utilisateur, {super.key, this.taille = 48});

  final Utilisateur? utilisateur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final initiales = Container(
      color: Palette.accent.withValues(alpha: context.isDark ? .22 : .12),
      alignment: Alignment.center,
      child: Text(
        (utilisateur?.initiales.isNotEmpty ?? false) ? utilisateur!.initiales : '?',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: taille * .36, color: lab.accent),
      ),
    );
    final photo = utilisateur?.photo;

    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: lab.border, width: 1.5),
      ),
      child: ClipOval(
        child: photo == null
            ? initiales
            : Image.network(
                photo,
                key: ValueKey(photo),
                fit: BoxFit.cover,
                width: taille,
                height: taille,
                // Pendant le chargement ou si l'image est introuvable : les initiales, jamais un trou.
                loadingBuilder: (context, enfant, progression) => progression == null ? enfant : initiales,
                errorBuilder: (_, _, _) => initiales,
              ),
      ),
    );
  }
}
