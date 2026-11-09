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
