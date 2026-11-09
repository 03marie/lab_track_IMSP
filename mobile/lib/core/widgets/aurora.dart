import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Fond « aurore » : halos de couleur qui dérivent lentement derrière le contenu.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.intensite = 1});

  final Widget child;

  /// 0 = discret, 1 = plein effet (écran de connexion).
  final double intensite;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  // Un AnimationController produit une valeur de 0 à 1 en boucle ;
  // on s'en sert pour déplacer les halos.
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final force = (context.isDark ? .55 : .28) * widget.intensite;
    return ColoredBox(
      color: lab.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = _ctrl.value * 2 * math.pi;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _Halo(Alignment(-.9 + .25 * math.sin(t), -1.0 + .15 * math.cos(t)), Palette.iris, force, 1.25),
                    _Halo(Alignment(1.0 + .2 * math.cos(t), -.35 + .2 * math.sin(t)), Palette.aqua, force * .8, 1.0),
                    _Halo(Alignment(-.4 + .3 * math.cos(t), 1.05 + .1 * math.sin(t)), const Color(0xFF8B5CF6), force * .6, 1.1),
                  ],
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo(this.alignement, this.couleur, this.opacite, this.rayon);
  final Alignment alignement;
  final Color couleur;
  final double opacite;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignement,
          radius: rayon,
          colors: [
            couleur.withValues(alpha: opacite),
            couleur.withValues(alpha: 0),
          ],
          stops: const [0, .65],
        ),
      ),
    );
  }
}
