import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/api/preferences.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/aurora.dart';
import '../../core/widgets/composants.dart';
import '../auth/auth_controller.dart';
import '../auth/serveur_sheet.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  Future<void> _deconnecter(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: Palette.rose, size: 32),
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir à nouveau vos identifiants.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).fermerSession();
  }

  Future<void> _changerServeur(BuildContext context, WidgetRef ref) async {
    final change = await ouvrirConfigurationServeur(context);
    // Les jetons appartiennent à l'ancien serveur : on referme la session.
    if (change == true) await ref.read(authProvider.notifier).fermerSession();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(utilisateurProvider);
    final serveur = ref.watch(serveurProvider);
    final theme = ref.watch(themeProvider);
    final lab = context.lab;

    return Scaffold(
      body: AuroraBackground(
        intensite: .5,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 140),
          children: [
            Entree(
              child: Column(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Palette.signatureSoft,
                      boxShadow: [BoxShadow(color: Palette.iris.withValues(alpha: .5), blurRadius: 36, spreadRadius: -6)],
                    ),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: lab.surface),
                      alignment: Alignment.center,
                      child: GradientText(u?.initiales ?? '?', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(u?.nomComplet ?? '', style: context.text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  if (u != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.or.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: context.or.withValues(alpha: .35)),
                      ),
                      child: Text(
                        u.roleLibelle,
                        style: TextStyle(color: context.or, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text('@${u?.username ?? ''}', style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Entree(index: 1, child: TitreSection('Apparence')),
            const SizedBox(height: 12),
            Entree(
              index: 2,
              child: _SelecteurTheme(
                valeur: theme,
                onChange: (m) {
                  HapticFeedback.selectionClick();
                  ref.read(themeProvider.notifier).definir(m);
                },
              ),
            ),
            const SizedBox(height: 28),
            const Entree(index: 3, child: TitreSection('Paramètres')),
            const SizedBox(height: 12),
            Entree(
              index: 4,
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _Ligne(
                      icone: Icons.dns_rounded,
                      couleur: Palette.aqua,
                      titre: 'Serveur',
                      sousTitre: serveur.replaceFirst(RegExp(r'^https?://'), ''),
                      onTap: () => _changerServeur(context, ref),
                    ),
                    Divider(indent: 70, color: lab.border),
                    _Ligne(
                      icone: Icons.key_rounded,
                      couleur: Palette.violet,
                      titre: 'Changer le mot de passe',
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _MotDePasseSheet(),
                      ),
                    ),
                    Divider(indent: 70, color: lab.border),
                    _Ligne(icone: Icons.info_rounded, couleur: context.or, titre: 'LabTrack', sousTitre: 'Version 1.0 · IMSP'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Entree(
              index: 5,
              child: Pressable(
                onTap: () => _deconnecter(context, ref),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: Palette.rose.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Palette.rose.withValues(alpha: .35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Palette.rose),
                      SizedBox(width: 10),
                      Text(
                        'Se déconnecter',
                        style: TextStyle(color: Palette.rose, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur segmenté avec un curseur qui glisse sous l'option choisie.
class _SelecteurTheme extends StatelessWidget {
  const _SelecteurTheme({required this.valeur, required this.onChange});

  final ThemeMode valeur;
  final ValueChanged<ThemeMode> onChange;

  static const _options = [
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Sombre'),
    (ThemeMode.light, Icons.light_mode_rounded, 'Clair'),
    (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
  ];

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final index = _options.indexWhere((o) => o.$1 == valeur);
    return Container(
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: lab.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lab.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final largeur = c.maxWidth / _options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: largeur * index,
                top: 0,
                bottom: 0,
                width: largeur,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: Palette.signatureSoft,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Palette.iris.withValues(alpha: .4), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final (mode, icone, libelle) in _options)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChange(mode),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icone, size: 18, color: mode == valeur ? Colors.white : lab.textMuted),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: 'Jakarta',
                                  color: mode == valeur ? Colors.white : lab.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                                child: Text(libelle),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.couleur, required this.titre, this.sousTitre, this.onTap});

  final IconData icone;
  final Color couleur;
  final String titre;
  final String? sousTitre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: .98,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: couleur.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icone, color: couleur, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (sousTitre != null && sousTitre!.isNotEmpty) Text(sousTitre!, style: context.text.bodySmall),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.lab.textMuted),
        ],
      ),
    ),
  );
}

class _MotDePasseSheet extends ConsumerStatefulWidget {
  const _MotDePasseSheet();

  @override
  ConsumerState<_MotDePasseSheet> createState() => _MotDePasseSheetState();
}

class _MotDePasseSheetState extends ConsumerState<_MotDePasseSheet> {
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      await ref.read(dioProvider).post<void>('auth/mot-de-passe/', data: {'ancien': _ancien.text, 'nouveau': _nouveau.text});
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe modifié')));
    } on DioException catch (e) {
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nouveau mot de passe', style: context.text.titleLarge),
        const SizedBox(height: 4),
        Text('8 caractères minimum, pas uniquement des chiffres.', style: context.text.bodySmall),
        const SizedBox(height: 20),
        TextField(
          controller: _ancien,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe actuel', prefixIcon: Icon(Icons.lock_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nouveau,
          obscureText: true,
          onSubmitted: (_) => _valider(),
          decoration: const InputDecoration(labelText: 'Nouveau mot de passe', prefixIcon: Icon(Icons.lock_rounded)),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 12),
          Text(
            _erreur!,
            style: const TextStyle(color: Palette.rose, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 22),
        GradientButton(label: 'Enregistrer', icone: Icons.check_rounded, chargement: _chargement, onPressed: _valider),
      ],
    ),
  );
}
