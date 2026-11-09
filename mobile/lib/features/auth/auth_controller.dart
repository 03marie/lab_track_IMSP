import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/api/modeles.dart';
import '../../core/api/preferences.dart';

/// État de la session : `null` = déconnecté, sinon l'utilisateur connecté.
///
/// Un `AsyncNotifier` expose un `AsyncValue` (chargement / données / erreur)
/// que l'interface et le routeur observent.
class AuthController extends AsyncNotifier<Utilisateur?> {
  static const _cleProfil = 'profil';

  @override
  Future<Utilisateur?> build() async {
    if (ref.read(serveurProvider).isEmpty) return null;
    if (await ref.read(jetonStoreProvider).access() == null) return null;

    try {
      return await _chargerProfil();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _effacer();
        return null;
      }
      // Serveur injoignable au démarrage : on garde la session avec le profil mémorisé ;
      // les écrans afficheront leur propre erreur réseau.
      final memorise = ref.read(prefsProvider).getString(_cleProfil);
      return memorise == null ? null : Utilisateur.fromJson(jsonDecode(memorise) as Map<String, dynamic>);
    }
  }

  Future<Utilisateur> _chargerProfil() async {
    final r = await ref.read(dioProvider).get<Map<String, dynamic>>('auth/moi/');
    final u = Utilisateur.fromJson(r.data!);
    await ref.read(prefsProvider).setString(_cleProfil, jsonEncode(u.toJson()));
    return u;
  }

  /// Lève une exception (message via `messageErreur`) si la connexion échoue.
  Future<void> connecter(String identifiant, String motDePasse) async {
    final dio = ref.read(dioProvider);
    try {
      final r = await dio.post<Map<String, dynamic>>(
        'auth/connexion/',
        data: {'username': identifiant.trim(), 'password': motDePasse},
      );
      await ref.read(jetonStoreProvider).enregistrer(access: r.data!['access'] as String, refresh: r.data!['refresh'] as String);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const FormatException('Identifiant ou mot de passe incorrect.');
      }
      rethrow;
    }
    state = AsyncData(await _chargerProfil());
  }

  Future<void> fermerSession() async {
    await _effacer();
    state = const AsyncData(null);
  }

  Future<void> _effacer() async {
    await ref.read(jetonStoreProvider).effacer();
    await ref.read(prefsProvider).remove(_cleProfil);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, Utilisateur?>(AuthController.new);

/// Raccourci : l'utilisateur connecté (null si aucun).
final utilisateurProvider = Provider<Utilisateur?>((ref) => ref.watch(authProvider).value);

/// Vérifie qu'un serveur LabTrack répond à cette adresse (401 = joignable mais non connecté).
Future<void> testerServeur(String adresse) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${normaliserServeur(adresse)}/api/v1/',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );
  try {
    await dio.get<dynamic>('auth/moi/');
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) return;
    throw FormatException(messageErreur(e));
  }
}
