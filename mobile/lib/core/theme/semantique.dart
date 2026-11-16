import 'package:flutter/material.dart';

import 'palette.dart';

/// Apparence d'une valeur métier (statut, type de mouvement…) : libellé, couleur, icône.
class Apparence {
  const Apparence(this.libelle, this.couleur, this.icone);
  final String libelle;
  final Color couleur;
  final IconData icone;
}

const statuts = <String, Apparence>{
  'disponible': Apparence('Disponible', Palette.emerald, Icons.check_circle_rounded),
  'emprunte': Apparence('Emprunté', Palette.amber, Icons.outbound_rounded),
  'en_maintenance': Apparence('En maintenance', Palette.rose, Icons.build_circle_rounded),
  'retire': Apparence('Retiré', Palette.slate, Icons.archive_rounded),
};

/// « 5 disponibles », « 1 emprunté », « 2 en maintenance ».
String libelleStatutCompte(String statut, int n) {
  final base = apparenceStatut(statut).libelle.toLowerCase();
  return n > 1 && statut != 'en_maintenance' ? '${base}s' : base;
}

Apparence apparenceStatut(String statut) => statuts[statut] ?? const Apparence('Inconnu', Palette.slate, Icons.help_rounded);

const etats = <String, Apparence>{
  'bon': Apparence('Bon état', Palette.emerald, Icons.verified_rounded),
  'use': Apparence('Usé', Palette.amber, Icons.timelapse_rounded),
  'defectueux': Apparence('Défectueux', Palette.rose, Icons.report_problem_rounded),
  'hors_service': Apparence('Hors service', Palette.slate, Icons.block_rounded),
};

Apparence apparenceEtat(String etat) => etats[etat] ?? const Apparence('Inconnu', Palette.slate, Icons.help_rounded);

const _mouvements = <String, Apparence>{
  'creation': Apparence('Création', Palette.teal, Icons.add_circle_rounded),
  'modification': Apparence('Modification', Palette.accent, Icons.edit_rounded),
  'emprunt': Apparence('Emprunt', Palette.amber, Icons.outbound_rounded),
  'retour': Apparence('Retour', Palette.emerald, Icons.assignment_return_rounded),
  'panne': Apparence('Panne', Palette.rose, Icons.report_rounded),
  'reparation': Apparence('Réparation', Palette.teal, Icons.build_rounded),
  'inventaire': Apparence('Inventaire', Palette.ochre, Icons.fact_check_rounded),
  'retrait': Apparence('Retrait', Palette.slate, Icons.archive_rounded),
};

Apparence apparenceMouvement(String type) =>
    _mouvements[type] ?? const Apparence('Événement', Palette.slate, Icons.circle_rounded);

/// Teintes posées, partagées par les catégories et les laboratoires.
const _tons = [
  Color(0xFF4F6BCB), // indigo
  Color(0xFF2F8C8C), // sarcelle
  Color(0xFF3E8E5E), // vert
  Color(0xFFB7832B), // ocre
  Color(0xFFC0566B), // rose
  Color(0xFF4A82B5), // bleu acier
  Color(0xFF8663B5), // violet
  Color(0xFFBF6B3A), // terre cuite
];

int _empreinte(String texte) => texte.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);

/// Icône et couleur d'une catégorie, devinées à partir de son nom (stables : même nom, même couleur).
({IconData icone, Color couleur}) visuelCategorie(String nom) {
  final n = nom.toLowerCase();
  if (n.contains('mesure')) return (icone: Icons.speed_rounded, couleur: _tons[0]);
  if (n.contains('ordinateur') || n.contains('informatique')) return (icone: Icons.laptop_mac_rounded, couleur: _tons[5]);
  if (n.contains('carte') || n.contains('électron') || n.contains('electron')) {
    return (icone: Icons.memory_rounded, couleur: _tons[2]);
  }
  if (n.contains('optique') || n.contains('micro')) return (icone: Icons.biotech_rounded, couleur: _tons[3]);
  if (n.contains('outil')) return (icone: Icons.handyman_rounded, couleur: _tons[7]);
  if (n.contains('chimie') || n.contains('verre')) return (icone: Icons.science_rounded, couleur: _tons[4]);
  return (icone: Icons.inventory_2_rounded, couleur: _tons[_empreinte(n) % _tons.length]);
}

/// Couleur stable par laboratoire (dérivée de son code).
Color couleurLabo(String code) => _tons[_empreinte(code) % _tons.length];

/// « Laboratoire d'électronique » → « Électronique » (nom court des cartes et des puces).
String nomCourtLabo(String nom) {
  final court = nom.replaceFirst(RegExp(r"^Laboratoire (d'|de |des |du )?", caseSensitive: false), '').trim();
  if (court.isEmpty) {
    return nom;
  }
  return court[0].toUpperCase() + court.substring(1);
}
