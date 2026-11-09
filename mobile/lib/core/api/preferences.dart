import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fourni dans main.dart (chargé avant le démarrage de l'app).
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider non initialisé'));

// --- Adresse du serveur (le PC qui fait tourner Docker) -----------------------

/// Transforme une saisie libre (« 192.168.1.20 », « 192.168.1.20:8000/ »…)
/// en adresse propre : `http://192.168.1.20:8000`. Port 8000 par défaut.
String normaliserServeur(String saisie) {
  var s = saisie.trim();
  if (s.isEmpty) return '';
  if (!RegExp(r'^https?://').hasMatch(s)) s = 'http://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) throw const FormatException('Adresse invalide');
  // `Uri.hasPort` est faux pour un port standard (80/443) même saisi : on lit le texte directement.
  final portSaisi = RegExp(r'^https?://[^/?#]+:(\d+)').firstMatch(s)?.group(1);
  final port = portSaisi != null ? int.parse(portSaisi) : 8000;
  final standard = (uri.scheme == 'http' && port == 80) || (uri.scheme == 'https' && port == 443);
  return '${uri.scheme}://${uri.host}${standard ? '' : ':$port'}';
}

class ServeurNotifier extends Notifier<String> {
  static const _cle = 'serveur';

  @override
  String build() => ref.read(prefsProvider).getString(_cle) ?? '';

  Future<void> definir(String saisie) async {
    final adresse = normaliserServeur(saisie);
    await ref.read(prefsProvider).setString(_cle, adresse);
    state = adresse;
  }
}

final serveurProvider = NotifierProvider<ServeurNotifier, String>(ServeurNotifier.new);

// --- Thème --------------------------------------------------------------------

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _cle = 'theme';

  @override
  ThemeMode build() {
    final v = ref.read(prefsProvider).getString(_cle);
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.dark);
  }

  Future<void> definir(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setString(_cle, mode.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// --- Jetons JWT (stockage chiffré du téléphone) -------------------------------

class JetonStore {
  const JetonStore([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;

  Future<String?> access() => _s.read(key: 'access');
  Future<String?> refresh() => _s.read(key: 'refresh');

  Future<void> enregistrer({required String access, String? refresh}) async {
    await _s.write(key: 'access', value: access);
    if (refresh != null) await _s.write(key: 'refresh', value: refresh);
  }

  Future<void> effacer() async {
    await _s.delete(key: 'access');
    await _s.delete(key: 'refresh');
  }
}

final jetonStoreProvider = Provider<JetonStore>((ref) => const JetonStore());
