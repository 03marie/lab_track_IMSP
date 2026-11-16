import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/semantique.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/dialogues.dart';
import '../auth/auth_controller.dart';
import 'equipements_repository.dart';
import 'widgets.dart';
import '../../core/widgets/feuille.dart';

/// Création (ou modification) d'un équipement.
///
/// Création : on remplit la fiche, l'équipement est enregistré dans la base avec son code unique,
/// puis l'écran « étiquette prête » propose le PDF A4 à imprimer.
class EquipementFormScreen extends ConsumerStatefulWidget {
  const EquipementFormScreen({super.key, this.existant, this.laboInitial});

  final Equipement? existant;
  final int? laboInitial;

  @override
  ConsumerState<EquipementFormScreen> createState() => _EquipementFormScreenState();
}

class _EquipementFormScreenState extends ConsumerState<EquipementFormScreen> {
  final _cle = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _emplacement = TextEditingController();
  final _marque = TextEditingController();
  final _modele = TextEditingController();
  final _serie = TextEditingController();
  final _description = TextEditingController();

  int? _categorie;
  int? _labo;
  DateTime? _date;
  File? _photo;
  bool _chargement = false;
  bool _tentative = false;
  String? _erreur;
  Equipement? _cree;

  bool get _edition => widget.existant != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    if (e != null) {
      _nom.text = e.nom;
      _emplacement.text = e.emplacement;
      _marque.text = e.marque;
      _modele.text = e.modele;
      _serie.text = e.numeroSerie;
      _description.text = e.description;
      _categorie = e.categorieId;
      _labo = e.laboratoireId;
      _date = e.dateAcquisition;
    } else {
      _labo = widget.laboInitial;
    }
  }

  @override
  void dispose() {
    for (final c in [_nom, _emplacement, _marque, _modele, _serie, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> _choisirPhoto() async {
    final source = await ouvrirFeuille<ImageSource?>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionPhoto(
                icone: Icons.photo_camera_rounded,
                couleur: context.accent,
                titre: 'Prendre une photo',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _OptionPhoto(
                icone: Icons.photo_library_rounded,
                couleur: Palette.teal,
                titre: 'Choisir dans la galerie',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (_photo != null)
                _OptionPhoto(
                  icone: Icons.delete_outline_rounded,
                  couleur: Palette.rose,
                  titre: 'Retirer la nouvelle photo',
                  onTap: () {
                    setState(() => _photo = null);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final fichier = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (fichier != null && mounted) setState(() => _photo = File(fichier.path));
    } on PlatformException {
      if (mounted) {
        notifier(context, 'Impossible d\'accéder à la caméra ou à la galerie. Vérifiez les autorisations.', erreur: true);
      }
    }
  }

  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date ?? aujourdhui,
      firstDate: DateTime(1990),
      lastDate: aujourdhui,
      helpText: 'Date d\'acquisition',
    );
    if (choisie != null) setState(() => _date = choisie);
  }

  Future<void> _nouvelleCategorie() async {
    final nom = await saisirTexte(
      context,
      icone: Icons.category_rounded,
      couleur: context.accent,
      titre: 'Nouvelle catégorie',
      message: 'Par exemple « Verrerie », « Capteurs », « Imprimantes ».',
      libelle: 'Nom de la catégorie',
      action: 'Créer',
    );
    if (nom == null || !mounted) return;
    try {
      final c = await ref.read(equipementsRepositoryProvider).creerCategorie(nom);
      ref.invalidate(categoriesProvider);
      if (mounted) setState(() => _categorie = c.id);
    } on DioException catch (e) {
      if (mounted) notifier(context, messageErreur(e), erreur: true);
    }
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    setState(() => _tentative = true);
    final formulaireValide = _cle.currentState!.validate();
    if (!formulaireValide || _categorie == null || _labo == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final donnees = DonneesEquipement(
      nom: _nom.text,
      categorie: _categorie!,
      laboratoire: _labo!,
      emplacement: _emplacement.text,
      marque: _marque.text,
      modele: _modele.text,
      numeroSerie: _serie.text,
      description: _description.text,
      dateAcquisition: _date,
      photo: _photo,
    );
    try {
      final repo = ref.read(equipementsRepositoryProvider);
      final e = _edition ? await repo.modifierEquipement(widget.existant!.id, donnees) : await repo.creerEquipement(donnees);
      rafraichirDonnees(ref);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      if (_edition) {
        notifier(context, 'Modifications enregistrées');
        context.pop();
      } else {
        setState(() => _cree = e);
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  /// Après une création : on repart d'un formulaire vide en gardant labo, catégorie, marque et modèle
  /// (pratique pour enregistrer plusieurs équipements du même type à la suite).
  void _creerUnAutre() {
    final nom = _nom.text;
    _nom.clear();
    _serie.clear();
    _description.clear();
    setState(() {
      _cree = null;
      _photo = null;
      _tentative = false;
      _erreur = null;
    });
    if (nom.isNotEmpty) _nom.text = nom;
  }

  // --- Interface -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cree = _cree;
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          child: cree != null ? _Succes(key: const ValueKey('succes'), e: cree, onAutre: _creerUnAutre) : _formulaire(context),
        ),
      ),
    );
  }

  Widget _formulaire(BuildContext context) {
    final utilisateur = ref.watch(utilisateurProvider);
    final categories = ref.watch(categoriesProvider);
    final labos = ref.watch(laboratoiresProvider);
    final lab = context.lab;

    return Form(
      key: _cle,
      child: ListView(
        key: const ValueKey('formulaire'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Entree(
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
                      Text(_edition ? 'Modifier l\'équipement' : 'Nouvel équipement', style: context.text.headlineSmall),
                      Text(
                        _edition ? widget.existant!.code : 'Une étiquette code-barres sera générée',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Entree(
            index: 1,
            child: _BlocPhoto(photo: _photo, existante: widget.existant?.photo, onTap: _choisirPhoto),
          ),
          const SizedBox(height: 22),
          const Entree(index: 2, child: TitreSection('Identification')),
          const SizedBox(height: 12),
          Entree(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nom,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Donnez un nom à l\'équipement' : null,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'équipement *',
                    hintText: 'Multimètre numérique',
                    prefixIcon: Icon(Icons.inventory_2_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                _EtiquetteChamp('Catégorie *', erreur: _tentative && _categorie == null),
                const SizedBox(height: 10),
                categories.when(
                  data: (liste) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in liste)
                        _ChipChoix(
                          libelle: c.nom,
                          icone: visuelCategorie(c.nom).icone,
                          couleur: visuelCategorie(c.nom).couleur,
                          actif: _categorie == c.id,
                          onTap: () => setState(() => _categorie = c.id),
                        ),
                      _ChipChoix(
                        libelle: 'Nouvelle',
                        icone: Icons.add_rounded,
                        couleur: context.accent,
                        actif: false,
                        pointille: true,
                        onTap: _nouvelleCategorie,
                      ),
                    ],
                  ),
                  loading: () => const Skeleton(height: 40, radius: 14),
                  error: (e, _) => Text(messageErreur(e), style: const TextStyle(color: Palette.rose)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Entree(index: 3, child: TitreSection('Emplacement')),
          const SizedBox(height: 12),
          Entree(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EtiquetteChamp('Laboratoire *', erreur: _tentative && _labo == null),
                const SizedBox(height: 10),
                labos.when(
                  data: (liste) {
                    final permis = liste.where((l) => utilisateur?.peutGererLabo(l.id) ?? false).toList();
                    if (permis.isEmpty) {
                      return Text(
                        'Vous ne gérez aucun laboratoire. Demandez à un administrateur de vous en attribuer un.',
                        style: context.text.bodySmall,
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final l in permis)
                          _ChipChoix(
                            libelle: nomCourtLabo(l.nom),
                            icone: Icons.science_rounded,
                            couleur: couleurLabo(l.code),
                            actif: _labo == l.id,
                            onTap: () => setState(() => _labo = l.id),
                          ),
                      ],
                    );
                  },
                  loading: () => const Skeleton(height: 40, radius: 14),
                  error: (e, _) => Text(messageErreur(e), style: const TextStyle(color: Palette.rose)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emplacement,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Emplacement précis',
                    hintText: 'Armoire A2, paillasse 1…',
                    prefixIcon: Icon(Icons.place_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Entree(index: 4, child: TitreSection('Détails')),
          const SizedBox(height: 12),
          Entree(
            index: 4,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marque,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Marque', prefixIcon: Icon(Icons.sell_rounded)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _modele,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Modèle'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serie,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Numéro de série', prefixIcon: Icon(Icons.numbers_rounded)),
                ),
                const SizedBox(height: 12),
                _ChampDate(date: _date, onTap: _choisirDate, onEffacer: () => setState(() => _date = null)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(padding: EdgeInsets.only(bottom: 44), child: Icon(Icons.notes_rounded)),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _erreur == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(top: 18),
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
                            style: const TextStyle(color: Palette.rose, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          BoutonPrincipal(
            label: _edition ? 'Enregistrer les modifications' : 'Créer et générer l\'étiquette',
            icone: _edition ? Icons.check_rounded : Icons.qr_code_2_rounded,
            chargement: _chargement,
            onPressed: _enregistrer,
          ),
        ],
      ),
    );
  }
}

// --- Éléments du formulaire ---------------------------------------------------

class _EtiquetteChamp extends StatelessWidget {
  const _EtiquetteChamp(this.texte, {required this.erreur});
  final String texte;
  final bool erreur;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(texte, style: context.text.labelLarge?.copyWith(color: erreur ? Palette.rose : context.lab.textMuted)),
      if (erreur) ...[
        const SizedBox(width: 8),
        const Text(
          '— à choisir',
          style: TextStyle(color: Palette.rose, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ],
    ],
  );
}

class _ChipChoix extends StatelessWidget {
  const _ChipChoix({
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.actif,
    required this.onTap,
    this.pointille = false,
  });

  final String libelle;
  final IconData icone;
  final Color couleur;
  final bool actif;
  final bool pointille;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Pressable(
      onTap: onTap,
      scale: .96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: actif ? couleur : lab.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: actif ? couleur : (pointille ? lab.accent.withValues(alpha: .6) : lab.border), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(actif ? Icons.check_rounded : icone, size: 18, color: actif ? Colors.white : context.lisible(couleur)),
            const SizedBox(width: 8),
            Text(
              libelle,
              style: TextStyle(color: actif ? Colors.white : lab.text, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlocPhoto extends StatelessWidget {
  const _BlocPhoto({required this.photo, required this.existante, required this.onTap});

  final File? photo;
  final String? existante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    final aImage = photo != null || existante != null;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: lab.surface,
          border: Border.all(color: context.accent.withValues(alpha: .35), width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.file(photo!, fit: BoxFit.cover)
            else if (existante != null)
              Image.network(existante!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            if (!aImage)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.accent.withValues(alpha: .14)),
                      child: Icon(Icons.add_a_photo_rounded, color: context.accent, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text('Ajouter une photo', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Facultatif · aide à reconnaître l\'équipement', style: context.text.bodySmall),
                  ],
                ),
              )
            else
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(99)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Changer',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionPhoto extends StatelessWidget {
  const _OptionPhoto({required this.icone, required this.couleur, required this.titre, required this.onTap});
  final IconData icone;
  final Color couleur;
  final String titre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
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

class _ChampDate extends StatelessWidget {
  const _ChampDate({required this.date, required this.onTap, required this.onEffacer});
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onEffacer;

  @override
  Widget build(BuildContext context) {
    final lab = context.lab;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date d\'acquisition',
          prefixIcon: const Icon(Icons.event_rounded),
          suffixIcon: date == null
              ? Icon(Icons.expand_more_rounded, color: lab.textMuted)
              : IconButton(icon: const Icon(Icons.close_rounded), onPressed: onEffacer),
        ),
        child: Text(
          date == null ? 'Non renseignée' : DateFormat('d MMMM yyyy', 'fr_FR').format(date!),
          style: TextStyle(color: date == null ? lab.textMuted : lab.text, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// --- Écran « étiquette prête » ---------------------------------------------------

class _Succes extends ConsumerWidget {
  const _Succes({super.key, required this.e, required this.onAutre});

  final Equipement e;
  final VoidCallback onAutre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab = context.lab;
    final visuel = visuelCategorie(e.categorieNom);
    final image = ref.watch(codeBarresProvider(e.id));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Transform.scale(scale: t.clamp(0, 1.15), child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.emerald),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Entree(
          index: 1,
          child: Text('Équipement créé', textAlign: TextAlign.center, style: context.text.headlineMedium),
        ),
        const SizedBox(height: 6),
        Entree(
          index: 2,
          child: Text(
            'Il est enregistré dans la base.\nL\'étiquette est prête à imprimer.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: lab.textMuted, height: 1.45),
          ),
        ),
        const SizedBox(height: 26),
        Entree(
          index: 3,
          child: SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconeTuile(icone: visuel.icone, couleur: visuel.couleur, taille: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                          Text(e.laboratoireNom, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 150,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: image.when(
                    data: (octets) => Image.memory(octets, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        messageErreur(err),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Palette.rose),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(e.code, style: styleCode.copyWith(fontSize: 15, color: context.accent)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        Entree(
          index: 4,
          child: BoutonPrincipal(
            label: 'Imprimer l\'étiquette (PDF A4)',
            icone: Icons.picture_as_pdf_rounded,
            onPressed: () => context.push('/etiquettes?ids=${e.id}'),
          ),
        ),
        const SizedBox(height: 12),
        Entree(
          index: 5,
          child: OutlinedButton.icon(
            onPressed: onAutre,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Créer un autre équipement'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: lab.text,
              side: BorderSide(color: lab.border, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Entree(
          index: 6,
          child: TextButton(
            onPressed: () => context.pushReplacement('/equipement/${e.id}'),
            style: TextButton.styleFrom(foregroundColor: lab.textMuted, minimumSize: const Size.fromHeight(48)),
            child: const Text('Voir la fiche de l\'équipement', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
