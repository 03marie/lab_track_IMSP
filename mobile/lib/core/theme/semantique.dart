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
  'creation': Apparence('Création', Palette.aqua, Icons.add_circle_rounded),
  'modification': Apparence('Modification', Palette.violet, Icons.edit_rounded),
  'emprunt': Apparence('Emprunt', Palette.amber, Icons.outbound_rounded),
  'retour': Apparence('Retour', Palette.emerald, Icons.assignment_return_rounded),
  'panne': Apparence('Panne', Palette.rose, Icons.report_rounded),
  'reparation': Apparence('Réparation', Palette.aqua, Icons.build_rounded),
  'inventaire': Apparence('Inventaire', Palette.gold, Icons.fact_check_rounded),
  'retrait': Apparence('Retrait', Palette.slate, Icons.archive_rounded),
};

Apparence apparenceMouvement(String type) =>
    _mouvements[type] ?? const Apparence('Événement', Palette.slate, Icons.circle_rounded);

/// Icône et teinte d'une catégorie, devinées à partir de son nom.
({IconData icone, List<Color> teintes}) visuelCategorie(String nom) {
  final n = nom.toLowerCase();
  if (n.contains('mesure')) return (icone: Icons.speed_rounded, teintes: const [Color(0xFF7C5CFF), Color(0xFFA78BFA)]);
  if (n.contains('ordinateur') || n.contains('informatique')) {
    return (icone: Icons.laptop_mac_rounded, teintes: const [Color(0xFF0EA5E9), Color(0xFF22D3EE)]);
  }
  if (n.contains('carte') || n.contains('électron') || n.contains('electron')) {
    return (icone: Icons.memory_rounded, teintes: const [Color(0xFF10B981), Color(0xFF34D399)]);
  }
  if (n.contains('optique') || n.contains('micro')) {
    return (icone: Icons.biotech_rounded, teintes: const [Color(0xFFF59E0B), Color(0xFFF2C46D)]);
  }
  if (n.contains('outil')) return (icone: Icons.handyman_rounded, teintes: const [Color(0xFFF43F5E), Color(0xFFFB7185)]);
  if (n.contains('chimie') || n.contains('verre')) {
    return (icone: Icons.science_rounded, teintes: const [Color(0xFFEC4899), Color(0xFFF472B6)]);
  }
  return (icone: Icons.inventory_2_rounded, teintes: const [Color(0xFF6366F1), Color(0xFF818CF8)]);
}

/// Teinte stable par laboratoire (dérivée de son code).
List<Color> teintesLaboratoire(String code) {
  const jeux = [
    [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
    [Color(0xFF10B981), Color(0xFF22D3EE)],
    [Color(0xFFF59E0B), Color(0xFFF43F5E)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF0EA5E9), Color(0xFF6366F1)],
  ];
  final h = code.codeUnits.fold<int>(0, (a, c) => a + c);
  return jeux[h % jeux.length];
}
