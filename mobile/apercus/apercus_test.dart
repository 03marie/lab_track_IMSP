// Captures d'écran de l'app avec des données factices (revue visuelle du design).
// Regénérer : flutter test --update-goldens apercus/   → images dans apercus/captures/
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:labtrack/app.dart';
import 'package:labtrack/core/api/modeles.dart';
import 'package:labtrack/core/api/preferences.dart';
import 'package:labtrack/features/auth/auth_controller.dart';
import 'package:labtrack/features/equipements/equipements_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _u = Utilisateur(id: 2, username: 'resp.elec', prenom: 'Koffi', nom: 'Mensah', role: 'responsable', roleLibelle: 'Responsable de laboratoire');

class _AuthConnecte extends AuthController {
  @override
  Future<Utilisateur?> build() async => _u;
}

class _AuthDeconnecte extends AuthController {
  @override
  Future<Utilisateur?> build() async => null;
}

Equipement _e(int id, String nom, String cat, String labo, String statut, {String empl = '', String marque = '', String modele = ''}) =>
    Equipement(
      id: id,
      code: 'IMSP-EQ-${id.toString().padLeft(4, '0')}',
      nom: nom,
      categorieNom: cat,
      laboratoireId: labo == 'Laboratoire d\'électronique' ? 1 : 2,
      laboratoireNom: labo,
      etat: statut == 'en_maintenance' ? 'defectueux' : 'bon',
      statut: statut,
      emplacement: empl,
      marque: marque,
      modele: modele,
      numeroSerie: id == 3 ? 'DS1ZA2024' : '',
      dateAcquisition: DateTime(2024, 3, 14),
      creeLe: DateTime.now().subtract(Duration(days: id)),
    );

const _elec = 'Laboratoire d\'électronique';
const _info = 'Laboratoire d\'informatique';
final _equipements = [
  _e(1, 'Multimètre numérique', 'Instruments de mesure', _elec, 'disponible', empl: 'Armoire A2', marque: 'Fluke', modele: '117'),
  _e(2, 'Multimètre numérique', 'Instruments de mesure', _elec, 'emprunte', empl: 'Armoire A2'),
  _e(3, 'Oscilloscope 100 MHz', 'Instruments de mesure', _elec, 'disponible', empl: 'Paillasse 1', marque: 'Rigol', modele: 'DS1104'),
  _e(4, 'Alimentation stabilisée', 'Instruments de mesure', _elec, 'en_maintenance', empl: 'Paillasse 2'),
  _e(5, 'Arduino Uno', 'Cartes de développement', _elec, 'disponible', empl: 'Armoire A3'),
  _e(7, 'ESP32 DevKit', 'Cartes de développement', _elec, 'emprunte', empl: 'Armoire A3'),
  _e(9, 'Ordinateur portable', 'Ordinateurs', _info, 'disponible', empl: 'Armoire B1'),
  _e(13, 'Microscope binoculaire', 'Optique', _elec, 'retire', empl: 'Armoire A4'),
];
const _stats = Statistiques(total: 13, parStatut: {'disponible': 8, 'emprunte': 3, 'en_maintenance': 1, 'retire': 1});
const _labos = [
  Laboratoire(id: 1, code: 'ELEC', nom: _elec, localisation: 'Bâtiment B, salle 12', nbEquipements: 9),
  Laboratoire(id: 2, code: 'INFO', nom: _info, localisation: 'Bâtiment A, salle 3', nbEquipements: 4),
];
final _historique = [
  Mouvement(id: 3, type: 'retour', auteur: 'Koffi Mensah', details: 'Rendu en bon état par Awa Diallo.', date: DateTime.now().subtract(const Duration(minutes: 42))),
  Mouvement(id: 2, type: 'emprunt', auteur: 'Koffi Mensah', details: 'TP d\'électronique L2 — retour prévu demain.', date: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
  Mouvement(id: 1, type: 'creation', auteur: 'Admin IMSP', details: 'Enregistré dans Laboratoire d\'électronique.', date: DateTime(2026, 10, 2, 9, 30)),
];

Future<void> _polices() async {
  final jakarta = FontLoader('Jakarta');
  for (final w in [400, 500, 600, 700, 800]) {
    jakarta.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final icones = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icones.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await _polices();
  });

  Future<ProviderContainer> monter(WidgetTester tester, {required bool connecte, ThemeMode theme = ThemeMode.dark}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    SharedPreferences.setMockInitialValues({'serveur': 'http://192.168.1.20:8000', 'theme': theme.name});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(connecte ? _AuthConnecte.new : _AuthDeconnecte.new),
        statistiquesProvider.overrideWith((ref, labo) async => labo == null
            ? _stats
            : labo == 1
                ? const Statistiques(total: 9, parStatut: {'disponible': 5, 'emprunte': 2, 'en_maintenance': 1, 'retire': 1})
                : const Statistiques(total: 4, parStatut: {'disponible': 3, 'emprunte': 1})),
        recentsProvider.overrideWith((ref) async => _equipements.reversed.take(4).toList()),
        laboratoiresProvider.overrideWith((ref) async => _labos),
        pageEquipementsProvider.overrideWith((ref, args) async {
          final f = args.$1;
          final liste = _equipements.where((e) => f.statut == null || e.statut == f.statut).toList();
          return PageResultats(total: liste.length, elements: liste, suivante: false);
        }),
        equipementProvider.overrideWith((ref, id) async => _equipements.firstWhere((e) => e.id == id)),
        historiqueProvider.overrideWith((ref, id) async => _historique),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const LabTrackApp()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    return container;
  }

  Future<void> capture(WidgetTester tester, String nom) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    debugDisableShadows = false;
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$nom.png'));
    debugDisableShadows = true;
  }

  testWidgets('connexion', (tester) async {
    await monter(tester, connecte: false);
    await capture(tester, '1-connexion');
  });

  testWidgets('accueil', (tester) async {
    await monter(tester, connecte: true);
    await capture(tester, '2-accueil');
  });

  testWidgets('equipements', (tester) async {
    final c = await monter(tester, connecte: true);
    c.read(routerProvider).go('/equipements');
    await capture(tester, '3-equipements');
  });

  testWidgets('detail', (tester) async {
    final c = await monter(tester, connecte: true);
    c.read(routerProvider).push('/equipement/3');
    await capture(tester, '4-detail');
  });

  testWidgets('laboratoires', (tester) async {
    final c = await monter(tester, connecte: true);
    c.read(routerProvider).go('/laboratoires');
    await capture(tester, '5-laboratoires');
  });

  testWidgets('profil clair', (tester) async {
    final c = await monter(tester, connecte: true, theme: ThemeMode.light);
    c.read(routerProvider).go('/profil');
    await capture(tester, '6-profil-clair');
  });

  testWidgets('accueil clair', (tester) async {
    await monter(tester, connecte: true, theme: ThemeMode.light);
    await capture(tester, '7-accueil-clair');
  });
}
