import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';
import '../theme/semantique.dart';

/// Rétrécit légèrement son enfant pendant l'appui : retour tactile immédiat.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .96, this.haptique = true});

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
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Carte « verre dépoli » : flou de l'arrière-plan + liseré lumineux.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28, this.flou = 24});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double flou;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: flou, sigmaY: flou),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: lab.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: lab.glassBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: context.isDark ? .07 : .5),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Carte de surface standard (sans flou : performante dans les listes).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 24, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final carte = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: lab.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: lab.border),
        boxShadow: [BoxShadow(color: lab.shadow, blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -12)],
      ),
      child: child,
    );
    return onTap == null ? carte : Pressable(onTap: onTap, scale: .975, child: carte);
  }
}

/// Bouton principal en dégradé signature, avec halo et état de chargement.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.onPressed, this.icone, this.chargement = false});

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
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: Palette.signatureSoft,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Palette.iris.withValues(alpha: .45),
                blurRadius: 28,
                offset: const Offset(0, 12),
                spreadRadius: -8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: chargement
                ? const SizedBox(
                    key: ValueKey('c'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('l'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: .2),
                      ),
                      if (icone != null) ...[const SizedBox(width: 10), Icon(icone, color: Colors.white, size: 20)],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de statut : point lumineux + libellé sur fond teinté.
class StatusPill extends StatelessWidget {
  const StatusPill(this.apparence, {super.key, this.compact = false});

  factory StatusPill.statut(String statut, {bool compact = false}) => StatusPill(apparenceStatut(statut), compact: compact);

  final Apparence apparence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = apparence.couleur;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? .14 : .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.withValues(alpha: .8), blurRadius: 8)],
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            apparence.libelle,
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: compact ? 11.5 : 12.5, letterSpacing: .2),
          ),
        ],
      ),
    );
  }
}

/// Tuile d'icône en dégradé (catégorie d'équipement, laboratoire…).
class GradientIcon extends StatelessWidget {
  const GradientIcon({super.key, required this.icone, required this.teintes, this.taille = 52, this.rayon = 16});

  final IconData icone;
  final List<Color> teintes;
  final double taille;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: teintes),
        boxShadow: [
          BoxShadow(color: teintes.first.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4),
        ],
      ),
      child: Icon(icone, color: Colors.white, size: taille * .5),
    );
  }
}

/// Apparition en fondu + glissement, décalée selon l'index (effet « cascade »).
class Entree extends StatefulWidget {
  const Entree({super.key, required this.child, this.index = 0, this.decalage = const Offset(0, 24)});

  final Widget child;
  final int index;
  final Offset decalage;

  @override
  State<Entree> createState() => _EntreeState();
}

class _EntreeState extends State<Entree> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _courbe = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 12)), () {
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

/// Bloc de chargement scintillant (« skeleton »).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 12});

  final double height;
  final double width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.lab.surfaceHigh;
    final reflet = context.isDark ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .9);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final x = -1.5 + 3 * _ctrl.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(begin: Alignment(x - 1, 0), end: Alignment(x + 1, 0), colors: [base, reflet, base]),
          ),
        );
      },
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
    final c = couleur ?? Palette.violet;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: .12),
              border: Border.all(color: c.withValues(alpha: .25)),
            ),
            child: Icon(icone, size: 38, color: c),
          ),
          const SizedBox(height: 20),
          Text(titre, textAlign: TextAlign.center, style: context.text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action!),
              style: TextButton.styleFrom(
                foregroundColor: c,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
          style: TextStyle(color: context.lab.textMuted, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.4),
        ),
        const Spacer(),
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(color: Palette.violet, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// Texte en dégradé signature (titres de marque).
class GradientText extends StatelessWidget {
  const GradientText(this.texte, {super.key, required this.style, this.gradient = Palette.signature});

  final String texte;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => gradient.createShader(Offset.zero & r.size),
      child: Text(texte, style: style),
    );
  }
}
