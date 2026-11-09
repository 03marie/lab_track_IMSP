import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Affichage bord à bord : l'app dessine sous les barres système (fond aurore visible partout).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeDateFormatting('fr_FR');
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Pas de nouvelle tentative automatique : en cas d'erreur réseau, l'écran affiche « Réessayer ».
      retry: (_, _) => null,
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const LabTrackApp(),
    ),
  );
}
