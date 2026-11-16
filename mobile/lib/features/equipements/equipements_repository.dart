import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';

/// Taille de page de l'API (PAGE_SIZE côté Django).
const taillePage = 50;

/// Filtres de la liste. Un « record » Dart : deux filtres identiques sont égaux,
/// donc Riverpod réutilise le même cache.
typedef FiltreEquipements = ({String recherche, String? statut, int? laboratoire, String tri});

const filtreParDefaut = (recherche: '', statut: null, laboratoire: null, tri: 'code');

class EquipementsRepository {
  EquipementsRepository(this._dio);
  final Dio _dio;

  Future<PageResultats<Equipement>> lister(FiltreEquipements f, {int page = 1}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      'equipements/',
      queryParameters: {
        'page': page,
        'ordering': f.tri,
        if (f.recherche.isNotEmpty) 'search': f.recherche,
        if (f.statut != null) 'statut': f.statut,
        if (f.laboratoire != null) 'laboratoire': f.laboratoire,
      },
    );
    return PageResultats.fromJson(r.data!, Equipement.fromJson);
  }

  Future<Equipement> detail(int id) async =>
      Equipement.fromJson((await _dio.get<Map<String, dynamic>>('equipements/$id/')).data!);

  /// Retourne `null` si aucun équipement ne porte ce code.
  Future<Equipement?> parCode(String code) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('equipements/par-code/${Uri.encodeComponent(code.trim())}/');
      return Equipement.fromJson(r.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Mouvement>> historique(int id) async {
    final r = await _dio.get<Map<String, dynamic>>('equipements/$id/historique/');
    return (r.data!['results'] as List).cast<Map<String, dynamic>>().map(Mouvement.fromJson).toList();
  }

  Future<Statistiques> statistiques({int? laboratoire}) async {
    final r = await _dio.get<Map<String, dynamic>>('equipements/statistiques/', queryParameters: {'laboratoire': ?laboratoire});
    return Statistiques.fromJson(r.data!);
  }

  Future<Uint8List> codeBarres(int id) async {
    final r = await _dio.get<List<int>>('equipements/$id/code-barres/', options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(r.data!);
  }

  Future<List<Laboratoire>> laboratoires() async {
    final r = await _dio.get<Map<String, dynamic>>('laboratoires/');
    return (r.data!['results'] as List).cast<Map<String, dynamic>>().map(Laboratoire.fromJson).toList();
  }

  // --- Écriture --------------------------------------------------------------

  Future<Laboratoire> creerLaboratoire({
    required String code,
    required String nom,
    String localisation = '',
    List<int> responsables = const [],
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      'laboratoires/',
      data: {'code': code, 'nom': nom, 'localisation': localisation, 'responsables': responsables},
    );
    return Laboratoire.fromJson(r.data!);
  }

  /// Échoue avec un 409 (message du serveur) si le laboratoire contient encore des équipements.
  Future<void> supprimerLaboratoire(int id) => _dio.delete<void>('laboratoires/$id/');

  Future<List<Categorie>> categories() async {
    final r = await _dio.get<Map<String, dynamic>>('categories/', queryParameters: {'page_size': 200});
    return (r.data!['results'] as List).cast<Map<String, dynamic>>().map(Categorie.fromJson).toList();
  }

  Future<Categorie> creerCategorie(String nom) async {
    final r = await _dio.post<Map<String, dynamic>>('categories/', data: {'nom': nom});
    return Categorie.fromJson(r.data!);
  }

  /// Utilisateurs « responsable » (pour désigner les responsables d'un laboratoire).
  Future<List<Utilisateur>> responsables() async {
    final r = await _dio.get<Map<String, dynamic>>('utilisateurs/', queryParameters: {'role': 'responsable'});
    return (r.data!['results'] as List).cast<Map<String, dynamic>>().map(Utilisateur.fromJson).toList();
  }

  Future<Equipement> creerEquipement(DonneesEquipement d) async {
    final r = await _dio.post<Map<String, dynamic>>('equipements/', data: await d.versFormData());
    return Equipement.fromJson(r.data!);
  }

  Future<Equipement> modifierEquipement(int id, DonneesEquipement d) async {
    final r = await _dio.patch<Map<String, dynamic>>('equipements/$id/', data: await d.versFormData());
    return Equipement.fromJson(r.data!);
  }

  /// Suppression définitive. Échoue avec un 409 si l'équipement a un historique : il faut alors le [retirer].
  Future<void> supprimerEquipement(int id) => _dio.delete<void>('equipements/$id/');

  Future<Equipement> retirer(int id, String motif) async {
    final r = await _dio.post<Map<String, dynamic>>('equipements/$id/retirer/', data: {'motif': motif});
    return Equipement.fromJson(r.data!);
  }

  /// Planche d'étiquettes A4 (PDF). `saut` = emplacements déjà utilisés sur une feuille entamée.
  Future<Uint8List> pdfEtiquettes({List<int>? ids, int? laboratoire, int saut = 0}) async {
    final r = await _dio.get<List<int>>(
      'equipements/etiquettes/',
      queryParameters: {if (ids != null) 'ids': ids.join(','), 'laboratoire': ?laboratoire, if (saut > 0) 'saut': saut},
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)),
    );
    return Uint8List.fromList(r.data!);
  }
}

/// Champs du formulaire d'équipement.
class DonneesEquipement {
  const DonneesEquipement({
    required this.nom,
    required this.categorie,
    required this.laboratoire,
    this.emplacement = '',
    this.marque = '',
    this.modele = '',
    this.numeroSerie = '',
    this.description = '',
    this.dateAcquisition,
    this.photo,
  });

  final String nom;
  final int categorie;
  final int laboratoire;
  final String emplacement;
  final String marque;
  final String modele;
  final String numeroSerie;
  final String description;
  final DateTime? dateAcquisition;

  /// Fichier photo local à envoyer (null = ne pas toucher à la photo existante).
  final File? photo;

  Future<FormData> versFormData() async {
    final date = dateAcquisition;
    return FormData.fromMap({
      'nom': nom.trim(),
      'categorie': categorie,
      'laboratoire': laboratoire,
      'emplacement': emplacement.trim(),
      'marque': marque.trim(),
      'modele': modele.trim(),
      'numero_serie': numeroSerie.trim(),
      'description': description.trim(),
      // Chaîne vide = « pas de date » (le serveur la lit comme null).
      'date_acquisition': date == null
          ? ''
          : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (photo != null)
        'photo': await MultipartFile.fromFile(photo!.path, filename: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    });
  }
}

final equipementsRepositoryProvider = Provider((ref) => EquipementsRepository(ref.watch(dioProvider)));

// --- Providers de lecture (mis en cache, rechargés à la demande) --------------

/// Une page de la liste. La liste charge chaque page uniquement quand on l'atteint en défilant.
final pageEquipementsProvider = FutureProvider.autoDispose.family<PageResultats<Equipement>, (FiltreEquipements, int)>(
  (ref, args) => ref.watch(equipementsRepositoryProvider).lister(args.$1, page: args.$2),
);

final equipementProvider = FutureProvider.autoDispose.family<Equipement, int>(
  (ref, id) => ref.watch(equipementsRepositoryProvider).detail(id),
);

final historiqueProvider = FutureProvider.autoDispose.family<List<Mouvement>, int>(
  (ref, id) => ref.watch(equipementsRepositoryProvider).historique(id),
);

final statistiquesProvider = FutureProvider.autoDispose.family<Statistiques, int?>(
  (ref, laboratoire) => ref.watch(equipementsRepositoryProvider).statistiques(laboratoire: laboratoire),
);

final recentsProvider = FutureProvider.autoDispose<List<Equipement>>((ref) async {
  final page = await ref.watch(equipementsRepositoryProvider).lister((
    recherche: '',
    statut: null,
    laboratoire: null,
    tri: '-cree_le',
  ));
  return page.elements.take(5).toList();
});

final laboratoiresProvider = FutureProvider.autoDispose<List<Laboratoire>>(
  (ref) => ref.watch(equipementsRepositoryProvider).laboratoires(),
);

final codeBarresProvider = FutureProvider.autoDispose.family<Uint8List, int>(
  (ref, id) => ref.watch(equipementsRepositoryProvider).codeBarres(id),
);

final categoriesProvider = FutureProvider.autoDispose<List<Categorie>>(
  (ref) => ref.watch(equipementsRepositoryProvider).categories(),
);

final responsablesProvider = FutureProvider.autoDispose<List<Utilisateur>>(
  (ref) => ref.watch(equipementsRepositoryProvider).responsables(),
);

/// À appeler après toute création, modification, suppression ou retrait :
/// les listes, compteurs et fiches se rechargent avec les données à jour.
void rafraichirDonnees(WidgetRef ref) {
  ref
    ..invalidate(pageEquipementsProvider)
    ..invalidate(equipementProvider)
    ..invalidate(historiqueProvider)
    ..invalidate(statistiquesProvider)
    ..invalidate(recentsProvider)
    ..invalidate(laboratoiresProvider)
    ..invalidate(categoriesProvider);
}
