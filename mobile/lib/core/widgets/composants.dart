import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';
import '../theme/semantique.dart';

/// Rétrécit très légèrement son enfant pendant l'appui : retour tactile immédiat.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .975, this.haptique = true});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptique;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _appuye = false;

  void _etat(bool v) {
    if (widget.onTap != null) setState(() => _appuye = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _etat(true),
      onTapUp: (_) => _etat(false),
      onTapCancel: () => _etat(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptique) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _appuye ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Carte standard : aplat, liseré net, ombre légère. Se détache clairement du fond.
///
/// `accent` ajoute un filet de couleur sur le bord gauche (statut, catégorie…) pour repérer
/// la carte d'un coup d'œil sans la surcharger.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final a = accent;
    final carte = Container(
      decoration: BoxDecoration(
        color: lab.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: lab.border),
        boxShadow: [BoxShadow(color: lab.shadow, blurRadius: 10, offset: const Offset(0, 3), spreadRadius: -4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            if (a != null) Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: a)),
          ],
        ),
      ),
    );
    return onTap == null ? carte : Pressable(onTap: onTap, child: carte);
  }
}

/// Bouton principal : aplat de la couleur d'accent, avec état de chargement.
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal({super.key, required this.label, this.onPressed, this.icone, this.chargement = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !chargement;
    return Pressable(
      onTap: actif ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          height: 52,
          decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: chargement
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icone != null) ...[Icon(icone, color: Colors.white, size: 20), const SizedBox(width: 10)],
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pastille de statut : point + libellé sur fond teinté.
class StatusPill extends StatelessWidget {
  const StatusPill(this.apparence, {super.key, this.compact = false});

  factory StatusPill.statut(String statut, {bool compact = false}) => StatusPill(apparenceStatut(statut), compact: compact);

  final Apparence apparence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = apparence.couleur;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: compact ? 3.5 : 5.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? .16 : .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            apparence.libelle,
            style: TextStyle(color: context.lisible(c), fontWeight: FontWeight.w600, fontSize: compact ? 11.5 : 12.5),
          ),
        ],
      ),
    );
  }
}

/// Tuile d'icône unie, teintée (catégorie d'équipement, laboratoire, action…).
class IconeTuile extends StatelessWidget {
  const IconeTuile({super.key, required this.icone, required this.couleur, this.taille = 44, this.rayon = 12});

  final IconData icone;
  final Color couleur;
  final double taille;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: context.isDark ? .20 : .14),
        borderRadius: BorderRadius.circular(rayon),
      ),
      child: Icon(icone, color: context.lisible(couleur), size: taille * .5),
    );
  }
}

/// Apparition discrète (fondu + léger glissement), décalée selon l'index.
class Entree extends StatefulWidget {
  const Entree({super.key, required this.child, this.index = 0, this.decalage = const Offset(0, 10)});

  final Widget child;
  final int index;
  final Offset decalage;

  @override
  State<Entree> createState() => _EntreeState();
}

class _EntreeState extends State<Entree> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final _courbe = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 30 * widget.index.clamp(0, 10)), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _courbe,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _courbe.value,
        child: Transform.translate(offset: widget.decalage * (1 - _courbe.value), child: child),
      ),
    );
  }
}

/// Bloc de chargement (« skeleton ») : simple pulsation, sans effet de brillance.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 10});

  final double height;
  final double width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(lab.surfaceHigh, lab.border, .55 * _ctrl.value),
        ),
      ),
    );
  }
}

/// État vide ou d'erreur, avec action optionnelle.
class EtatVide extends StatelessWidget {
  const EtatVide({super.key, required this.icone, required this.titre, this.message, this.action, this.onAction, this.couleur});

  final IconData icone;
  final String titre;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? context.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .12)),
            child: Icon(icone, size: 32, color: c),
          ),
          const SizedBox(height: 18),
          Text(titre, textAlign: TextAlign.center, style: context.text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action!),
              style: TextButton.styleFrom(
                foregroundColor: c,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Titre de section : libellé en petites capitales + action à droite.
class TitreSection extends StatelessWidget {
  const TitreSection(this.titre, {super.key, this.action, this.onAction});

  final String titre;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          titre.toUpperCase(),
          style: TextStyle(color: context.lab.textMuted, fontWeight: FontWeight.w600, fontSize: 11.5, letterSpacing: 1.1),
        ),
        const Spacer(),
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
