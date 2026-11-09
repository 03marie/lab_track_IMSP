import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';

/// Coquille des onglets principaux avec la barre de navigation flottante.
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
      extendBody: true,
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
    (Icons.space_dashboard_rounded, 'Accueil'),
    (Icons.inventory_2_rounded, 'Matériel'),
    (Icons.science_rounded, 'Labos'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final bas = MediaQuery.paddingOf(context).bottom;

    Widget onglet(int i) => Expanded(
      child: _Onglet(icone: _onglets[i].$1, libelle: _onglets[i].$2, actif: index == i, onTap: () => onSelection(i)),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bas + 12),
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: lab.glass,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: lab.glassBorder),
                    boxShadow: [BoxShadow(color: lab.shadow, blurRadius: 30, offset: const Offset(0, 12))],
                  ),
                  child: Row(children: [onglet(0), onglet(1), const SizedBox(width: 76), onglet(2), onglet(3)]),
                ),
              ),
            ),
            Positioned(top: 0, child: _BoutonScan(onTap: onScan)),
          ],
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({required this.icone, required this.libelle, required this.actif, required this.onTap});

  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Pressable(
      onTap: onTap,
      haptique: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            padding: EdgeInsets.symmetric(horizontal: actif ? 16 : 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: actif
                  ? LinearGradient(colors: [Palette.iris.withValues(alpha: .24), Palette.aqua.withValues(alpha: .16)])
                  : null,
            ),
            child: actif
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => Palette.signature.createShader(r),
                    child: Icon(icone, size: 24),
                  )
                : Icon(icone, size: 24, color: lab.textMuted),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontFamily: 'Jakarta',
              fontSize: 11,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: actif ? lab.text : lab.textMuted,
            ),
            child: Text(libelle, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
        ],
      ),
    );
  }
}

/// Bouton central : dégradé signature + onde lumineuse qui pulse.
class _BoutonScan extends StatefulWidget {
  const _BoutonScan({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BoutonScan> createState() => _BoutonScanState();
}

class _BoutonScanState extends State<_BoutonScan> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onTap,
      haptique: false,
      scale: .9,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_ctrl.value);
                return Container(
                  width: 64 + 22 * t,
                  height: 64 + 22 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.aqua.withValues(alpha: .55 * (1 - t)), width: 2),
                  ),
                );
              },
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Palette.signatureSoft,
                border: Border.all(color: Colors.white.withValues(alpha: .25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Palette.iris.withValues(alpha: .6),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
