import 'package:flutter/material.dart';

/// Ouvre une feuille modale en bas de l'écran. **À utiliser à la place de `showModalBottomSheet`.**
///
/// Deux protections, valables pour toutes les feuilles de l'application :
///
/// 1. `useRootNavigator: true` — la feuille recouvre tout l'écran, barre de navigation comprise.
///    (Sans cela, sur les onglets, la barre du bas masque le bas de la feuille.)
/// 2. `SafeArea` — le contenu reste au-dessus de la zone des boutons système du téléphone
///    (barre « Retour / Accueil / Applications »). L'application s'affiche bord à bord : sans cette
///    protection, le dernier bouton d'une feuille (ex. « Créer le laboratoire ») passe sous ces boutons.
///    Le clavier est géré à part par chaque feuille (`viewInsets`) ; SafeArea ne double pas cette marge.
///
/// Un test automatique interdit l'appel direct à `showModalBottomSheet` ailleurs que dans ce fichier.
Future<T?> ouvrirFeuille<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    builder: (contexte) => SafeArea(top: false, child: builder(contexte)),
  );
}
