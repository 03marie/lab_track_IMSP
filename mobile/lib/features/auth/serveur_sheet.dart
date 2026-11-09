import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/preferences.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';
import 'auth_controller.dart';

/// Ouvre la feuille de configuration du serveur. Retourne `true` si l'adresse a changé.
Future<bool?> ouvrirConfigurationServeur(BuildContext context) =>
    showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _ServeurSheet());

enum _Test { aucun, encours, ok, echec }

class _ServeurSheet extends ConsumerStatefulWidget {
  const _ServeurSheet();

  @override
  ConsumerState<_ServeurSheet> createState() => _ServeurSheetState();
}

class _ServeurSheetState extends ConsumerState<_ServeurSheet> {
  late final _champ = TextEditingController(text: ref.read(serveurProvider).replaceFirst(RegExp(r'^https?://'), ''));
  var _test = _Test.aucun;
  String? _message;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _tester() async {
    setState(() {
      _test = _Test.encours;
      _message = null;
    });
    try {
      await testerServeur(_champ.text);
      HapticFeedback.lightImpact();
      setState(() {
        _test = _Test.ok;
        _message = 'Serveur LabTrack joignable.';
      });
    } on FormatException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _test = _Test.echec;
        _message = e.message;
      });
    }
  }

  Future<void> _enregistrer() async {
    try {
      final avant = ref.read(serveurProvider);
      await ref.read(serveurProvider.notifier).definir(_champ.text);
      if (mounted) Navigator.pop(context, avant != ref.read(serveurProvider));
    } on FormatException catch (e) {
      setState(() {
        _test = _Test.echec;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final couleurTest = switch (_test) {
      _Test.ok => Palette.emerald,
      _Test.echec => Palette.rose,
      _ => lab.textMuted,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(icone: Icons.dns_rounded, teintes: [Palette.iris, Palette.aqua], taille: 48, rayon: 15),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Serveur LabTrack', style: context.text.titleLarge),
                    Text('Le PC qui fait tourner Docker', style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _champ,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() => _test = _Test.aucun),
            onSubmitted: (_) => _enregistrer(),
            decoration: const InputDecoration(
              labelText: 'Adresse du serveur',
              hintText: '192.168.1.20:8000',
              prefixIcon: Icon(Icons.lan_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sur le PC, la commande « hostname -I » affiche son adresse IP. '
            'Le téléphone doit être connecté au même Wi-Fi.',
            style: context.text.bodySmall,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _message == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: couleurTest.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: couleurTest.withValues(alpha: .3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_test == _Test.ok ? Icons.check_circle_rounded : Icons.error_rounded, color: couleurTest, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(color: couleurTest, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: OutlinedButton.icon(
                    onPressed: _test == _Test.encours ? null : _tester,
                    icon: _test == _Test.encours
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Tester'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lab.text,
                      side: BorderSide(color: lab.border, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(label: 'Enregistrer', icone: Icons.check_rounded, onPressed: _enregistrer),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
