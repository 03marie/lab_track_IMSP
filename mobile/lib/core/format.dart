import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _jour = DateFormat('d MMM yyyy', 'fr_FR');
final _heure = DateFormat('HH:mm', 'fr_FR');

String formatDate(DateTime? d) => d == null ? '—' : _jour.format(d);

/// « à l'instant », « il y a 5 min », « hier à 14:02 », « 12 nov. 2026 · 14:02 ».
String formatRelatif(DateTime d) {
  final maintenant = DateTime.now();
  final ecart = maintenant.difference(d);
  if (ecart.inMinutes < 1) return 'à l\'instant';
  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  final aujourdhui = DateUtils.dateOnly(maintenant);
  final jour = DateUtils.dateOnly(d);
  if (jour == aujourdhui) return 'aujourd\'hui à ${_heure.format(d)}';
  if (jour == aujourdhui.subtract(const Duration(days: 1))) return 'hier à ${_heure.format(d)}';
  return '${_jour.format(d)} · ${_heure.format(d)}';
}

String salutation() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

/// Nombre qui « monte » jusqu'à sa valeur (compteurs du tableau de bord).
class CompteurAnime extends StatelessWidget {
  const CompteurAnime(this.valeur, {super.key, this.style, this.duree = const Duration(milliseconds: 1100)});

  final int valeur;
  final TextStyle? style;
  final Duration duree;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valeur.toDouble()),
      duration: duree,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
