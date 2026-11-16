import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import '../../core/api/client.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';
import 'equipements_repository.dart';

/// Clé de requête du PDF : (identifiants séparés par des virgules, laboratoire ou 0, emplacements à sauter).
/// Un « record » de types simples : deux demandes identiques partagent le même résultat en cache.
typedef CleEtiquettes = (String ids, int labo, int saut);

final pdfEtiquettesProvider = FutureProvider.autoDispose.family<Uint8List, CleEtiquettes>((ref, cle) {
  final ids = cle.$1.isEmpty ? null : cle.$1.split(',').map(int.parse).toList();
  return ref.watch(equipementsRepositoryProvider).pdfEtiquettes(ids: ids, laboratoire: cle.$2 == 0 ? null : cle.$2, saut: cle.$3);
});

/// Aperçu, impression et partage de la planche d'étiquettes A4 (3 × 8 étiquettes).
class EtiquettesScreen extends ConsumerStatefulWidget {
  const EtiquettesScreen({super.key, this.ids = '', this.laboratoire, this.titre});

  final String ids;
  final int? laboratoire;
  final String? titre;

  @override
  ConsumerState<EtiquettesScreen> createState() => _EtiquettesScreenState();
}

class _EtiquettesScreenState extends ConsumerState<EtiquettesScreen> {
  static const _emplacementsParFeuille = 24;
  int _saut = 0;

  CleEtiquettes get _cle => (widget.ids, widget.laboratoire ?? 0, _saut);

  int? get _nbEtiquettes => widget.ids.isEmpty ? null : widget.ids.split(',').length;

  void _changerSaut(int delta) {
    final nouveau = (_saut + delta).clamp(0, _emplacementsParFeuille - 1);
    if (nouveau == _saut) return;
    HapticFeedback.selectionClick();
    setState(() => _saut = nouveau);
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final pdf = ref.watch(pdfEtiquettesProvider(_cle));
    final nb = _nbEtiquettes;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: lab.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: lab.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: lab.text),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Étiquettes A4', style: context.text.headlineSmall),
                        Text(
                          widget.titre ?? (nb == null ? 'Planche du laboratoire' : '$nb étiquette${nb > 1 ? 's' : ''}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: pdf.when(
                data: (octets) => PdfPreview(
                  // Le PDF est déjà généré par le serveur : on le renvoie tel quel, sans le recomposer.
                  build: (_) async => octets,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: 'etiquettes-labtrack.pdf',
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  maxPageWidth: 560,
                  padding: const EdgeInsets.only(top: 4),
                  previewPageMargin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  scrollViewDecoration: BoxDecoration(color: lab.background),
                  pdfPreviewPageDecoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  actionBarTheme: PdfActionBarTheme(
                    backgroundColor: lab.surface,
                    iconColor: context.accent,
                    textStyle: TextStyle(color: lab.text, fontWeight: FontWeight.w700),
                    height: 64,
                  ),
                  loadingWidget: const CircularProgressIndicator(),
                  onError: (context, erreur) => EtatVide(
                    icone: Icons.picture_as_pdf_rounded,
                    titre: 'Aperçu impossible',
                    message: 'Le PDF a bien été généré mais ne peut pas être affiché : $erreur',
                    couleur: Palette.rose,
                  ),
                ),
                loading: () => const _Generation(),
                error: (e, _) => Center(
                  child: EtatVide(
                    icone: Icons.cloud_off_rounded,
                    titre: 'Génération impossible',
                    message: messageErreur(e),
                    action: 'Réessayer',
                    couleur: Palette.rose,
                    onAction: () => ref.invalidate(pdfEtiquettesProvider),
                  ),
                ),
              ),
            ),
            _BarreFeuille(saut: _saut, max: _emplacementsParFeuille - 1, onChange: _changerSaut),
          ],
        ),
      ),
    );
  }
}

/// Réglage « feuille déjà entamée » : on saute les emplacements déjà décollés pour ne rien gaspiller.
class _BarreFeuille extends StatelessWidget {
  const _BarreFeuille({required this.saut, required this.max, required this.onChange});

  final int saut;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
      decoration: BoxDecoration(
        color: lab.surface,
        border: Border(top: BorderSide(color: lab.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, color: context.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Feuille déjà entamée ?', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  saut == 0
                      ? 'Les étiquettes démarrent en haut à gauche.'
                      : '$saut emplacement${saut > 1 ? 's' : ''} déjà utilisé${saut > 1 ? 's' : ''} sont laissés vides.',
                  style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          _BoutonPas(icone: Icons.remove_rounded, actif: saut > 0, onTap: () => onChange(-1)),
          SizedBox(
            width: 38,
            child: Text(
              '$saut',
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _BoutonPas(icone: Icons.add_rounded, actif: saut < max, onTap: () => onChange(1)),
        ],
      ),
    );
  }
}

class _BoutonPas extends StatelessWidget {
  const _BoutonPas({required this.icone, required this.actif, required this.onTap});
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: actif ? onTap : null,
    haptique: false,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.accent.withValues(alpha: actif ? .16 : .06),
      ),
      child: Icon(icone, color: context.accent.withValues(alpha: actif ? 1 : .35)),
    ),
  );
}

class _Generation extends StatelessWidget {
  const _Generation();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 150,
          height: 212,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.all(14),
          child: const Column(
            children: [
              Skeleton(height: 28, radius: 6),
              SizedBox(height: 10),
              Skeleton(height: 28, radius: 6),
              SizedBox(height: 10),
              Skeleton(height: 28, radius: 6),
              SizedBox(height: 10),
              Skeleton(height: 28, radius: 6),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Génération du PDF…', style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted)),
      ],
    ),
  );
}
