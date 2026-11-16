import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';

/// Coquille des onglets principaux : le contenu au-dessus, une barre de navigation **opaque** en bas.
///
/// La barre est posée sous le contenu (pas par-dessus) : rien ne défile derrière elle et rien ne peut
/// passer dessous. Elle descend jusqu'au bord de l'écran et inclut la zone des boutons système du téléphone.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _aller(int index) {
    HapticFeedback.selectionClick();
    // Re-toucher l'onglet actif ramène à sa racine.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _BarreNavigation(
        index: shell.currentIndex,
        onSelection: _aller,
        onScan: () {
          HapticFeedback.mediumImpact();
          context.push('/scanner');
        },
      ),
    );
  }
}

class _BarreNavigation extends StatelessWidget {
  const _BarreNavigation({required this.index, required this.onSelection, required this.onScan});

  final int index;
  final ValueChanged<int> onSelection;
  final VoidCallback onScan;

  static const _onglets = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Accueil'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Matériel'),
    (Icons.science_outlined, Icons.science_rounded, 'Labos'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    Widget onglet(int i) => Expanded(
      child: _Onglet(
        icone: _onglets[i].$1,
        iconeActive: _onglets[i].$2,
        libelle: _onglets[i].$3,
        actif: index == i,
        onTap: () => onSelection(i),
      ),
    );

    return Material(
      color: lab.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: lab.border)),
        ),
        // SafeArea : la barre s'étend sous les boutons système et ses icônes restent au-dessus.
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                onglet(0),
                onglet(1),
                _BoutonScan(onTap: onScan),
                onglet(2),
                onglet(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.icone,
    required this.iconeActive,
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  final IconData icone;
  final IconData iconeActive;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final couleur = actif ? lab.accent : lab.textMuted;
    return Pressable(
      onTap: onTap,
      haptique: false,
      scale: .94,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(actif ? iconeActive : icone, size: 24, color: couleur),
          const SizedBox(height: 3),
          Text(
            libelle,
            maxLines: 1,
            style: TextStyle(fontSize: 11, fontWeight: actif ? FontWeight.w700 : FontWeight.w500, color: couleur),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Scanner » au centre de la barre : le seul élément plein, pour le repérer tout de suite.
class _BoutonScan extends StatelessWidget {
  const _BoutonScan({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        haptique: false,
        scale: .94,
        child: Center(
          child: Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
