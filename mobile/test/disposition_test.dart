// Garde-fous d'affichage : aucun contenu ne doit passer sous la barre de navigation du bas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labtrack/core/widgets/feuille.dart';

const _hauteurEcran = 800.0;
const _hauteurBarre = 100.0;
const _inseteSysteme = 48.0; // hauteur de la barre de boutons système du téléphone

/// Reproduit l'architecture de l'app : un écran à barre de navigation, dont le contenu
/// vit dans son propre navigateur (comme les onglets de la coquille LabTrack).
Widget _appli(void Function(BuildContext) ouvrir) => MaterialApp(
  home: Scaffold(
    extendBody: true,
    bottomNavigationBar: const SizedBox(
      height: _hauteurBarre,
      child: ColoredBox(color: Colors.blue),
    ),
    body: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (contexte) => Center(
          child: ElevatedButton(onPressed: () => ouvrir(contexte), child: const Text('ouvrir')),
        ),
      ),
    ),
  ),
);

/// Ouvre une feuille contenant un bouton collé en bas, puis tente de le toucher.
/// Retourne `true` si le bouton a bien reçu le toucher (donc n'est pas recouvert par la barre).
Future<bool> _boutonDuBasAtteignable(WidgetTester tester, Future<void> Function(BuildContext, WidgetBuilder) ouvrir) async {
  tester.view.physicalSize = const Size(400, _hauteurEcran);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var touche = false;
  Widget feuille(BuildContext _) => SizedBox(
    height: 300,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ElevatedButton(key: const Key('bas'), onPressed: () => touche = true, child: const Text('Enregistrer')),
    ),
  );
  await tester.pumpWidget(_appli((c) => ouvrir(c, feuille)));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bas')), warnIfMissed: false);
  await tester.pump();
  return touche;
}

void main() {
  testWidgets('hypothèse : le contenu d\'un onglet voit la hauteur de la barre dans MediaQuery.padding.bottom', (tester) async {
    tester.view.physicalSize = const Size(400, _hauteurEcran);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double? vu;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: const SizedBox(height: _hauteurBarre),
          body: Builder(
            builder: (c) {
              vu = MediaQuery.paddingOf(c).bottom;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(vu, _hauteurBarre, reason: 'Les écrans utilisent MediaQuery.paddingOf(context).bottom comme marge basse.');
  });

  testWidgets('CONTRÔLE : avec showModalBottomSheet, le bouton du bas est recouvert par la barre (le défaut)', (tester) async {
    final atteint = await _boutonDuBasAtteignable(tester, (c, b) => showModalBottomSheet<void>(context: c, builder: b));
    expect(atteint, isFalse, reason: 'Ce test doit reproduire le défaut, sinon il ne prouve rien.');
  });

  testWidgets('ouvrirFeuille : le bouton du bas est atteignable, la barre ne le masque plus', (tester) async {
    final atteint = await _boutonDuBasAtteignable(tester, (c, b) => ouvrirFeuille<void>(context: c, builder: b));
    expect(atteint, isTrue);
  });

  testWidgets('ouvrirFeuille : le bouton du bas reste AU-DESSUS des boutons système du téléphone', (tester) async {
    tester.view.physicalSize = const Size(400, _hauteurEcran);
    tester.view.devicePixelRatio = 1;
    // Affichage bord à bord : le système réserve 48 px en bas pour ses boutons (Retour / Accueil / Applications).
    tester.view.padding = const FakeViewPadding(bottom: _inseteSysteme);
    tester.view.viewPadding = const FakeViewPadding(bottom: _inseteSysteme);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ouvrirFeuille<void>(
                  context: c,
                  builder: (_) => SizedBox(
                    height: 300,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ElevatedButton(key: const Key('creer'), onPressed: () {}, child: const Text('Créer')),
                    ),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    final basDuBouton = tester.getRect(find.byKey(const Key('creer'))).bottom;
    expect(
      basDuBouton,
      lessThanOrEqualTo(_hauteurEcran - _inseteSysteme),
      reason: 'Le bouton ne doit pas passer sous la barre de boutons du téléphone.',
    );
  });

  testWidgets('CONTRÔLE : sans SafeArea (ancien code), le bouton du bas passe sous les boutons système', (tester) async {
    tester.view.physicalSize = const Size(400, _hauteurEcran);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: _inseteSysteme);
    tester.view.viewPadding = const FakeViewPadding(bottom: _inseteSysteme);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: c,
                  useRootNavigator: true,
                  builder: (_) => SizedBox(
                    height: 300,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ElevatedButton(key: const Key('creer'), onPressed: () {}, child: const Text('Créer')),
                    ),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    final basDuBouton = tester.getRect(find.byKey(const Key('creer'))).bottom;
    expect(
      basDuBouton,
      greaterThan(_hauteurEcran - _inseteSysteme),
      reason: 'Ce test doit reproduire le défaut signalé, sinon il ne prouve rien.',
    );
  });

  test('aucun code n\'appelle showModalBottomSheet directement (utiliser ouvrirFeuille)', () {
    final fautifs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('core/widgets/feuille.dart')) continue;
      if (RegExp(r'showModalBottomSheet\s*[<(]').hasMatch(f.readAsStringSync())) fautifs.add(f.path);
    }
    expect(
      fautifs,
      isEmpty,
      reason: 'Une feuille ouverte avec showModalBottomSheet passe SOUS la barre de navigation des onglets.',
    );
  });
}
