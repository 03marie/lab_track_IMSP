import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import '../equipements/equipements_repository.dart';
import '../equipements/widgets.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with SingleTickerProviderStateMixin {
  // Le contrôleur pilote la caméra. On ne cherche que du Code 128 : détection plus rapide et plus fiable.
  final _camera = MobileScannerController(formats: const [BarcodeFormat.code128]);
  late final _laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  bool _occupe = false; // une fiche est affichée : on ignore les détections
  bool _succes = false; // flash vert du cadre
  String? _dernierCode;
  DateTime _ignorerJusqua = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _laser.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _surDetection(BarcodeCapture capture) {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || _occupe) return;
    // Après fermeture d'une fiche, le même code encore devant la caméra ne doit pas la rouvrir aussitôt.
    if (code == _dernierCode && DateTime.now().isBefore(_ignorerJusqua)) return;
    _traiter(code);
  }

  Future<void> _traiter(String code) async {
    setState(() {
      _occupe = true;
      _succes = true;
      _dernierCode = code;
    });
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    final allerFiche = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FicheResultat(code: code),
    );
    if (!mounted) return;
    setState(() {
      _occupe = false;
      _succes = false;
      _ignorerJusqua = DateTime.now().add(const Duration(milliseconds: 2500));
    });
    if (allerFiche != null) context.push('/equipement/$allerFiche');
  }

  Future<void> _saisieManuelle() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _DialogueSaisie());
    if (code != null && code.trim().isNotEmpty) _traiter(code.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final bas = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, contraintes) {
            final taille = contraintes.biggest;
            // Fenêtre de scan large et basse : adaptée aux codes-barres linéaires.
            final fenetre = Rect.fromCenter(
              center: Offset(taille.width / 2, taille.height * .44),
              width: taille.width * .84,
              height: 180,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camera,
                  scanWindow: fenetre,
                  onDetect: _surDetection,
                  errorBuilder: (context, erreur) => _ErreurCamera(erreur: erreur),
                  placeholderBuilder: (_) => const ColoredBox(color: Colors.black),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _laser,
                    builder: (context, _) => CustomPaint(
                      painter: _CadrePainter(
                        fenetre: fenetre,
                        laser: Curves.easeInOutSine.transform(_laser.value),
                        succes: _succes,
                      ),
                    ),
                  ),
                ),
                // Barre du haut
                Positioned(
                  top: haut + 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _BoutonVerreSombre(icone: Icons.close_rounded, onTap: () => context.pop()),
                      const Spacer(),
                      const _PastilleVerre(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Scanner',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _camera,
                        builder: (context, etat, _) {
                          final allumee = etat.torchState == TorchState.on;
                          return _BoutonVerreSombre(
                            icone: allumee ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            actif: allumee,
                            onTap: etat.torchState == TorchState.unavailable ? null : () => _camera.toggleTorch(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Consigne sous le cadre
                Positioned(
                  top: fenetre.bottom + 28,
                  left: 32,
                  right: 32,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _succes ? 'Code détecté' : 'Placez le code-barres de l\'étiquette dans le cadre',
                      key: ValueKey(_succes),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _succes ? Palette.emerald : Colors.white.withValues(alpha: .9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
                      ),
                    ),
                  ),
                ),
                // Saisie manuelle (étiquette abîmée)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: bas + 28,
                  child: Center(
                    child: Pressable(
                      onTap: _saisieManuelle,
                      child: const _PastilleVerre(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Saisir le code manuellement',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Voile sombre percé d'une fenêtre, coins lumineux et faisceau laser.
class _CadrePainter extends CustomPainter {
  _CadrePainter({required this.fenetre, required this.laser, required this.succes});

  final Rect fenetre;
  final double laser;
  final bool succes;

  @override
  void paint(Canvas canvas, Size size) {
    final cadre = RRect.fromRectAndRadius(fenetre, const Radius.circular(26));

    // Voile autour de la fenêtre
    final voile = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(cadre)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(voile, Paint()..color = Colors.black.withValues(alpha: .62));

    // Liseré fin
    canvas.drawRRect(
      cadre,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .18),
    );

    // Coins en dégradé (ou verts en cas de succès)
    final shader = (succes ? const LinearGradient(colors: [Palette.emerald, Palette.emerald]) : Palette.signature).createShader(
      fenetre,
    );
    final coin = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    const l = 34.0;
    const r = 26.0;
    final f = fenetre;
    final coins = Path()
      // haut gauche
      ..moveTo(f.left, f.top + l)
      ..lineTo(f.left, f.top + r)
      ..arcToPoint(Offset(f.left + r, f.top), radius: const Radius.circular(r))
      ..lineTo(f.left + l, f.top)
      // haut droit
      ..moveTo(f.right - l, f.top)
      ..lineTo(f.right - r, f.top)
      ..arcToPoint(Offset(f.right, f.top + r), radius: const Radius.circular(r))
      ..lineTo(f.right, f.top + l)
      // bas droit
      ..moveTo(f.right, f.bottom - l)
      ..lineTo(f.right, f.bottom - r)
      ..arcToPoint(Offset(f.right - r, f.bottom), radius: const Radius.circular(r))
      ..lineTo(f.right - l, f.bottom)
      // bas gauche
      ..moveTo(f.left + l, f.bottom)
      ..lineTo(f.left + r, f.bottom)
      ..arcToPoint(Offset(f.left, f.bottom - r), radius: const Radius.circular(r))
      ..lineTo(f.left, f.bottom - l);
    canvas.drawPath(coins, coin);

    if (succes) {
      canvas.drawRRect(cadre, Paint()..color = Palette.emerald.withValues(alpha: .16));
      return;
    }

    // Faisceau laser horizontal avec halo
    final y = f.top + 18 + (f.height - 36) * laser;
    final faisceau = Rect.fromLTWH(f.left + 18, y - 1.5, f.width - 36, 3);
    canvas.drawRect(
      faisceau.inflate(10),
      Paint()
        ..shader = LinearGradient(
          colors: [Palette.aqua.withValues(alpha: 0), Palette.aqua.withValues(alpha: .35), Palette.aqua.withValues(alpha: 0)],
        ).createShader(faisceau)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(faisceau, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0022D3EE), Palette.aqua, Color(0xFFFFFFFF), Palette.aqua, Color(0x0022D3EE)],
        ).createShader(faisceau),
    );
  }

  @override
  bool shouldRepaint(_CadrePainter old) => old.laser != laser || old.succes != succes || old.fenetre != fenetre;
}

/// Résultat d'un scan : charge l'équipement et l'affiche, ou signale un code inconnu.
/// Renvoie l'id de l'équipement si l'utilisateur veut ouvrir sa fiche.
class _FicheResultat extends ConsumerStatefulWidget {
  const _FicheResultat({required this.code});
  final String code;

  @override
  ConsumerState<_FicheResultat> createState() => _FicheResultatState();
}

class _FicheResultatState extends ConsumerState<_FicheResultat> {
  late final Future<Equipement?> _recherche = ref.read(equipementsRepositoryProvider).parCode(widget.code);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.paddingOf(context).bottom + 24),
      child: FutureBuilder<Equipement?>(
        future: _recherche,
        builder: (context, snap) {
          final Widget contenu;
          if (snap.connectionState != ConnectionState.done) {
            contenu = _ChargementResultat(code: widget.code);
          } else if (snap.hasError) {
            contenu = _Probleme(
              icone: Icons.cloud_off_rounded,
              titre: 'Recherche impossible',
              message: messageErreur(snap.error!),
              code: widget.code,
            );
          } else if (snap.data == null) {
            contenu = _Probleme(
              icone: Icons.help_center_rounded,
              titre: 'Code inconnu',
              message: 'Ce code-barres n\'est associé à aucun équipement enregistré dans LabTrack.',
              code: widget.code,
            );
          } else {
            contenu = _Trouve(e: snap.data!);
          }
          return AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: contenu),
          );
        },
      ),
    );
  }
}

class _ChargementResultat extends StatelessWidget {
  const _ChargementResultat({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 18),
        Text('Recherche de $code…', style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted)),
      ],
    ),
  );
}

class _Trouve extends StatelessWidget {
  const _Trouve({required this.e});
  final Equipement e;

  @override
  Widget build(BuildContext context) {
    final visuel = visuelCategorie(e.categorieNom);
    final statut = apparenceStatut(e.statut);
    final lieu = [e.laboratoireNom, e.emplacement].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Palette.emerald, size: 20),
            const SizedBox(width: 8),
            Text('Équipement identifié', style: context.text.labelLarge?.copyWith(color: Palette.emerald)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            GradientIcon(icone: visuel.icone, teintes: visuel.teintes, taille: 64, rayon: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  Text(e.code, style: styleCode.copyWith(color: Palette.violet, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statut.couleur.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statut.couleur.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Icon(statut.icone, color: statut.couleur, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statut.libelle,
                      style: TextStyle(color: statut.couleur, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (lieu.isNotEmpty) Text(lieu, style: context.text.bodySmall),
                  ],
                ),
              ),
              StatusPill(apparenceEtat(e.etat), compact: true),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GradientButton(label: 'Voir la fiche', icone: Icons.arrow_forward_rounded, onPressed: () => Navigator.pop(context, e.id)),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: context.lab.textMuted, minimumSize: const Size.fromHeight(48)),
          child: const Text('Scanner un autre équipement', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _Probleme extends StatelessWidget {
  const _Probleme({required this.icone, required this.titre, required this.message, required this.code});

  final IconData icone;
  final String titre;
  final String message;
  final String code;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.rose.withValues(alpha: .12),
          border: Border.all(color: Palette.rose.withValues(alpha: .3)),
        ),
        child: Icon(icone, color: Palette.rose, size: 36),
      ),
      const SizedBox(height: 16),
      Text(titre, style: context.text.titleLarge),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: context.lab.surfaceHigh, borderRadius: BorderRadius.circular(10)),
        child: Text(code, style: styleCode.copyWith(color: context.lab.text)),
      ),
      const SizedBox(height: 12),
      Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted),
      ),
      const SizedBox(height: 22),
      GradientButton(label: 'Réessayer', icone: Icons.qr_code_scanner_rounded, onPressed: () => Navigator.pop(context)),
    ],
  );
}

class _DialogueSaisie extends StatefulWidget {
  const _DialogueSaisie();

  @override
  State<_DialogueSaisie> createState() => _DialogueSaisieState();
}

class _DialogueSaisieState extends State<_DialogueSaisie> {
  final _champ = TextEditingController(text: 'IMSP-EQ-');

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saisir un code'),
    content: TextField(
      controller: _champ,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      style: styleCode.copyWith(fontSize: 16, color: context.lab.text),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.view_week_rounded), hintText: 'IMSP-EQ-0001'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () => Navigator.pop(context, _champ.text), child: const Text('Rechercher')),
    ],
  );
}

class _ErreurCamera extends StatelessWidget {
  const _ErreurCamera({required this.erreur});
  final MobileScannerException erreur;

  @override
  Widget build(BuildContext context) {
    final refus = erreur.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Palette.ink950,
      child: Center(
        child: EtatVide(
          icone: refus ? Icons.no_photography_rounded : Icons.videocam_off_rounded,
          titre: refus ? 'Accès à la caméra refusé' : 'Caméra indisponible',
          message: refus
              ? 'Autorisez l\'accès à la caméra dans les réglages du téléphone pour scanner les étiquettes.'
              : 'La caméra n\'a pas pu démarrer. Vous pouvez saisir le code manuellement.',
          couleur: Palette.rose,
        ),
      ),
    );
  }
}

class _BoutonVerreSombre extends StatelessWidget {
  const _BoutonVerreSombre({required this.icone, this.onTap, this.actif = false});

  final IconData icone;
  final VoidCallback? onTap;
  final bool actif;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: actif ? Palette.gold.withValues(alpha: .9) : Colors.white.withValues(alpha: .14),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
          ),
          child: Icon(icone, color: actif ? Palette.ink950 : Colors.white.withValues(alpha: onTap == null ? .4 : 1)),
        ),
      ),
    ),
  );
}

class _PastilleVerre extends StatelessWidget {
  const _PastilleVerre({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: child,
      ),
    ),
  );
}
