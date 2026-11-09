import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/api/preferences.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/aurora.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/logo.dart';
import 'auth_controller.dart';
import 'serveur_sheet.dart';

class ConnexionScreen extends ConsumerStatefulWidget {
  const ConnexionScreen({super.key});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  final _focusMdp = FocusNode();
  bool _masque = true;
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _identifiant.dispose();
    _motDePasse.dispose();
    _focusMdp.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    FocusScope.of(context).unfocus();
    if (!_formulaire.currentState!.validate()) return;
    if (ref.read(serveurProvider).isEmpty) {
      final change = await ouvrirConfigurationServeur(context);
      if (change != true) return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      await ref.read(authProvider.notifier).connecter(_identifiant.text, _motDePasse.text);
      HapticFeedback.mediumImpact();
      // Le routeur redirige automatiquement vers l'accueil.
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final serveur = ref.watch(serveurProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Entree(child: Center(child: LogoLabTrack(taille: 92))),
                    const SizedBox(height: 28),
                    Entree(
                      index: 1,
                      child: Column(
                        children: [
                          Text('LabTrack', textAlign: TextAlign.center, style: context.text.displaySmall),
                          const SizedBox(height: 8),
                          Text(
                            'La traçabilité des équipements\nde l\'IMSP, au bout des doigts.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(color: lab.textMuted, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Entree(
                      index: 2,
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        child: Form(
                          key: _formulaire,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Connexion', style: context.text.titleLarge),
                              const SizedBox(height: 4),
                              Text('Accès réservé au personnel des laboratoires', style: context.text.bodySmall),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _identifiant,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.username],
                                onFieldSubmitted: (_) => _focusMdp.requestFocus(),
                                validator: (v) => (v ?? '').trim().isEmpty ? 'Saisissez votre identifiant' : null,
                                decoration: const InputDecoration(
                                  labelText: 'Identifiant',
                                  prefixIcon: Icon(Icons.person_rounded),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _motDePasse,
                                focusNode: _focusMdp,
                                obscureText: _masque,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _connecter(),
                                validator: (v) => (v ?? '').isEmpty ? 'Saisissez votre mot de passe' : null,
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _masque = !_masque),
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                      child: Icon(
                                        _masque ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        key: ValueKey(_masque),
                                        color: lab.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: _erreur == null
                                    ? const SizedBox(width: double.infinity, height: 22)
                                    : Container(
                                        margin: const EdgeInsets.symmetric(vertical: 16),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Palette.rose.withValues(alpha: .1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Palette.rose.withValues(alpha: .3)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_rounded, color: Palette.rose, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _erreur!,
                                                style: const TextStyle(
                                                  color: Palette.rose,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              GradientButton(
                                label: 'Se connecter',
                                icone: Icons.arrow_forward_rounded,
                                chargement: _chargement,
                                onPressed: _connecter,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Entree(
                      index: 3,
                      child: Center(
                        child: Pressable(
                          onTap: () => ouvrirConfigurationServeur(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: lab.glass,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: lab.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: serveur.isEmpty ? Palette.gold : Palette.emerald,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (serveur.isEmpty ? Palette.gold : Palette.emerald).withValues(alpha: .8),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  serveur.isEmpty ? 'Configurer le serveur' : serveur.replaceFirst(RegExp(r'^https?://'), ''),
                                  style: TextStyle(color: lab.text, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.tune_rounded, size: 16, color: lab.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'IMSP · Projet de simplification administrative',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(fontSize: 11.5, letterSpacing: .3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran affiché le temps de restaurer la session au démarrage.
class DemarrageScreen extends StatelessWidget {
  const DemarrageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoLabTrack(taille: 96),
              const SizedBox(height: 24),
              GradientText('LabTrack', style: context.text.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
