import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import 'preferences.dart';

/// Client HTTP vers l'API Django.
///
/// - ajoute le jeton JWT à chaque requête ;
/// - si le serveur répond 401 (jeton expiré), tente une fois de le renouveler
///   avec le jeton « refresh », puis rejoue la requête ;
/// - si le renouvellement échoue, ferme la session.
final dioProvider = Provider<Dio>((ref) {
  final serveur = ref.watch(serveurProvider);
  final store = ref.watch(jetonStoreProvider);

  final options = BaseOptions(
    baseUrl: '$serveur/api/v1/',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  );
  final dio = Dio(options);

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (requete, suite) async {
        final jeton = await store.access();
        if (jeton != null) requete.headers['Authorization'] = 'Bearer $jeton';
        suite.next(requete);
      },
      onError: (erreur, suite) async {
        final requete = erreur.requestOptions;
        final routeAuth = requete.path.startsWith('auth/connexion') || requete.path.startsWith('auth/rafraichir');
        if (erreur.response?.statusCode != 401 || routeAuth || requete.extra['rejouee'] == true) {
          return suite.next(erreur);
        }

        final refresh = await store.refresh();
        if (refresh != null) {
          try {
            final brut = Dio(options);
            final r = await brut.post<Map<String, dynamic>>('auth/rafraichir/', data: {'refresh': refresh});
            final nouveau = r.data!['access'] as String;
            await store.enregistrer(access: nouveau);
            requete
              ..extra['rejouee'] = true
              ..headers['Authorization'] = 'Bearer $nouveau';
            return suite.resolve(await brut.fetch(requete));
          } on DioException catch (_) {
            // Renouvellement impossible : on ferme la session ci-dessous.
          }
        }
        await ref.read(authProvider.notifier).fermerSession();
        suite.next(erreur);
      },
    ),
  );
  return dio;
});

/// Message lisible (en français) pour n'importe quelle erreur réseau ou API.
String messageErreur(Object erreur) {
  if (erreur is DioException) {
    switch (erreur.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.sendTimeout:
        return 'Serveur injoignable. Vérifiez que le téléphone est sur le même Wi-Fi que le PC serveur, '
            'et que l\'adresse du serveur est correcte.';
      case DioExceptionType.receiveTimeout:
        return 'Le serveur met trop de temps à répondre. Réessayez.';
      default:
        break;
    }
    final reponse = erreur.response;
    final data = reponse?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      if (data.isNotEmpty) {
        final premier = data.entries.first;
        final valeur = premier.value is List ? (premier.value as List).join(' ') : '${premier.value}';
        return premier.key == 'non_field_errors' ? valeur : '${premier.key} : $valeur';
      }
    }
    if (data is List && data.isNotEmpty) return data.join(' ');
    return switch (reponse?.statusCode) {
      401 => 'Session expirée. Reconnectez-vous.',
      403 => 'Accès refusé.',
      404 => 'Élément introuvable.',
      final int code when code >= 500 => 'Erreur du serveur ($code).',
      _ => 'Une erreur est survenue.',
    };
  }
  if (erreur is FormatException) return erreur.message;
  return 'Une erreur inattendue est survenue.';
}
