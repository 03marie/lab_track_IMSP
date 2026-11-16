import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/api/preferences.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/dialogues.dart';
import '../equipements/equipements_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/serveur_sheet.dart';
import '../../core/widgets/feuille.dart';

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
      body: ColoredBox(
        color: lab.background,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Entree(child: _EnTeteProfil(u: u)),
            const SizedBox(height: 26),
            Entree(index: 1, child: _InfosProfil(u: u)),
            const SizedBox(height: 30),
            const Entree(index: 2, child: TitreSection('Apparence')),
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
                      couleur: Palette.teal,
                      titre: 'Serveur',
                      sousTitre: serveur.replaceFirst(RegExp(r'^https?://'), ''),
                      onTap: () => _changerServeur(context, ref),
                    ),
                    Divider(indent: 70, color: lab.border),
                    _Ligne(
                      icone: Icons.key_rounded,
                      couleur: context.accent,
                      titre: 'Changer le mot de passe',
                      onTap: () => ouvrirFeuille<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _MotDePasseSheet(),
                      ),
                    ),
                    Divider(indent: 70, color: lab.border),
                    _Ligne(
                      icone: Icons.info_rounded,
                      couleur: context.accent,
                      titre: 'LabTrack',
                      sousTitre: 'Version 1.2 · IMSP',
                    ),
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
                  decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(11)),
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
        BoutonPrincipal(label: 'Enregistrer', icone: Icons.check_rounded, chargement: _chargement, onPressed: _valider),
      ],
    ),
  );
}

// --- En-tête : photo de profil -------------------------------------------------

class _EnTeteProfil extends ConsumerStatefulWidget {
  const _EnTeteProfil({required this.u});
  final Utilisateur? u;

  @override
  ConsumerState<_EnTeteProfil> createState() => _EnTeteProfilState();
}

class _EnTeteProfilState extends ConsumerState<_EnTeteProfil> {
  bool _envoi = false;

  Future<void> _changerPhoto() async {
    final u = widget.u;
    final choix = await ouvrirFeuille<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Photo de profil', style: context.text.titleLarge),
              const SizedBox(height: 8),
              _OptionPhoto(
                icone: Icons.photo_camera_rounded,
                couleur: context.accent,
                titre: 'Prendre une photo',
                valeur: 'camera',
              ),
              _OptionPhoto(
                icone: Icons.photo_library_rounded,
                couleur: Palette.teal,
                titre: 'Choisir dans la galerie',
                valeur: 'galerie',
              ),
              if (u?.photo != null)
                _OptionPhoto(
                  icone: Icons.delete_outline_rounded,
                  couleur: Palette.rose,
                  titre: 'Supprimer ma photo',
                  valeur: 'supprimer',
                ),
            ],
          ),
        ),
      ),
    );
    if (choix == null || !mounted) return;
    final auth = ref.read(authProvider.notifier);

    setState(() => _envoi = true);
    try {
      if (choix == 'supprimer') {
        await auth.supprimerPhoto();
        if (mounted) notifier(context, 'Photo de profil supprimée');
      } else {
        final fichier = await ImagePicker().pickImage(
          source: choix == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 900,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.front,
        );
        if (fichier == null) return;
        await auth.modifierProfil(photo: File(fichier.path));
        HapticFeedback.mediumImpact();
        if (mounted) notifier(context, 'Photo de profil mise à jour');
      }
    } on DioException catch (e) {
      if (mounted) notifier(context, messageErreur(e), erreur: true);
    } on PlatformException {
      if (mounted) {
        notifier(context, 'Impossible d\'accéder à la caméra ou à la galerie. Vérifiez les autorisations.', erreur: true);
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final lab = context.lab;
    return Column(
      children: [
        Pressable(
          onTap: _envoi ? null : _changerPhoto,
          child: SizedBox(
            width: 136,
            height: 136,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarUtilisateur(u, taille: 120),
                if (_envoi)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .5)),
                        child: const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.accent,
                      border: Border.all(color: lab.background, width: 3),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 21),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(u?.nomComplet ?? '', style: context.text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (u != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: context.accent.withValues(alpha: .4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 16, color: context.accent),
                const SizedBox(width: 6),
                Text(
                  u.roleLibelle,
                  style: TextStyle(color: context.accent, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('Touchez la photo pour la changer', style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
      ],
    );
  }
}

class _OptionPhoto extends StatelessWidget {
  const _OptionPhoto({required this.icone, required this.couleur, required this.titre, required this.valeur});
  final IconData icone;
  final Color couleur;
  final String titre;
  final String valeur;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => Navigator.pop(context, valeur),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: couleur.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
      child: Icon(icone, color: couleur),
    ),
    title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

// --- Informations du compte ----------------------------------------------------

class _InfosProfil extends ConsumerWidget {
  const _InfosProfil({required this.u});
  final Utilisateur? u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = u;
    if (user == null) return const SizedBox.shrink();
    final labos = ref.watch(laboratoiresProvider).value ?? const <Laboratoire>[];
    final geres = labos.where((l) => user.laboratoiresGeres.contains(l.id)).toList();

    final lignes = <(IconData, Color, String, String)>[
      (Icons.alternate_email_rounded, context.accent, 'Identifiant', user.username),
      (Icons.mail_rounded, Palette.teal, 'E-mail', user.email),
      (Icons.phone_rounded, Palette.emerald, 'Téléphone', user.telephone),
      (Icons.badge_rounded, Palette.amber, 'Matricule', user.matricule),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: TitreSection('Mes informations')),
            Pressable(
              onTap: () => ouvrirFeuille<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _CoordonneesSheet(u: user),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: context.accent.withValues(alpha: .4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 15, color: context.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Modifier',
                      style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, (icone, couleur, libelle, valeur)) in lignes.indexed) ...[
                if (i > 0) Divider(color: context.lab.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: couleur.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icone, color: couleur, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(libelle, style: context.text.bodySmall),
                            const SizedBox(height: 1),
                            Text(
                              valeur.isEmpty ? 'Non renseigné' : valeur,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: valeur.isEmpty ? context.lab.textMuted : context.lab.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (user.role == 'admin' || geres.isNotEmpty) ...[
          const SizedBox(height: 14),
          SurfaceCard(
            accent: Palette.teal,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: Palette.teal, size: 20),
                    const SizedBox(width: 10),
                    Text('Laboratoires gérés', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (user.role == 'admin')
                  Text(
                    'Administrateur : accès à tous les laboratoires.',
                    style: context.text.bodyMedium?.copyWith(color: context.lab.textMuted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in geres)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: couleurLabo(l.code), borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            l.nom,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CoordonneesSheet extends ConsumerStatefulWidget {
  const _CoordonneesSheet({required this.u});
  final Utilisateur u;

  @override
  ConsumerState<_CoordonneesSheet> createState() => _CoordonneesSheetState();
}

class _CoordonneesSheetState extends ConsumerState<_CoordonneesSheet> {
  final _cle = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.u.email);
  late final _telephone = TextEditingController(text: widget.u.telephone);
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      await ref.read(authProvider.notifier).modifierProfil(email: _email.text, telephone: _telephone.text);
      if (!mounted) return;
      Navigator.pop(context);
      notifier(context, 'Informations enregistrées');
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
    child: Form(
      key: _cle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mes coordonnées', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text('Le nom, le rôle et l\'identifiant sont gérés par l\'administration.', style: context.text.bodySmall),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: (v) {
              final t = (v ?? '').trim();
              return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Adresse e-mail invalide';
            },
            decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_rounded)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            onFieldSubmitted: (_) => _enregistrer(),
            decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_rounded)),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            Text(
              _erreur!,
              style: const TextStyle(color: Palette.rose, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 22),
          BoutonPrincipal(label: 'Enregistrer', icone: Icons.check_rounded, chargement: _chargement, onPressed: _enregistrer),
        ],
      ),
    ),
  );
}
