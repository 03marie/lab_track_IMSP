import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/connexion_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/api/modeles.dart';
import 'features/equipements/detail_screen.dart';
import 'features/equipements/equipement_form_screen.dart';
import 'features/equipements/equipements_repository.dart';
import 'features/equipements/equipements_screen.dart';
import 'features/equipements/etiquettes_screen.dart';
import 'features/laboratoires/laboratoires_screen.dart';
import 'features/profil/profil_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/shell/shell_screen.dart';

/// Routes de l'application. Le routeur redirige selon l'état de connexion.
final routerProvider = Provider<GoRouter>((ref) {
  final rafraichir = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => rafraichir.value++);
  ref.onDispose(rafraichir.dispose);

  return GoRouter(
    initialLocation: '/accueil',
    refreshListenable: rafraichir,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final ici = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) return ici == '/demarrage' ? null : '/demarrage';
      final connecte = auth.value != null;
      if (!connecte) return ici == '/connexion' ? null : '/connexion';
      if (ici == '/connexion' || ici == '/demarrage') return '/accueil';
      return null;
    },
    routes: [
      GoRoute(path: '/demarrage', builder: (_, _) => const DemarrageScreen()),
      GoRoute(
        path: '/connexion',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ConnexionScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/accueil', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/equipements',
                builder: (_, state) => EquipementsScreen(statutInitial: state.uri.queryParameters['statut']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/laboratoires', builder: (_, _) => const LaboratoiresScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profil', builder: (_, _) => const ProfilScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/scanner',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ScanScreen(),
          transitionDuration: const Duration(milliseconds: 420),
          transitionsBuilder: (_, animation, _, child) {
            final courbe = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: courbe,
              child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(courbe), child: child),
            );
          },
        ),
      ),
      // « nouveau » doit être déclaré AVANT « :id », sinon « nouveau » serait pris pour un identifiant.
      GoRoute(
        path: '/equipement/nouveau',
        builder: (_, state) => EquipementFormScreen(laboInitial: int.tryParse(state.uri.queryParameters['labo'] ?? '')),
      ),
      GoRoute(
        path: '/equipement/:id',
        builder: (_, state) => DetailEquipementScreen(id: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'modifier',
            builder: (_, state) {
              final id = int.parse(state.pathParameters['id']!);
              // La fiche est passée en paramètre depuis la page de détail ; sinon on la recharge.
              final fournie = state.extra;
              if (fournie is Equipement) return EquipementFormScreen(existant: fournie);
              return _ChargerPuisModifier(id: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/etiquettes',
        builder: (_, state) => EtiquettesScreen(
          ids: state.uri.queryParameters['ids'] ?? '',
          laboratoire: int.tryParse(state.uri.queryParameters['labo'] ?? ''),
          titre: state.uri.queryParameters['titre'],
        ),
      ),
      GoRoute(
        path: '/laboratoire/:id',
        builder: (_, state) => EquipementsScreen(
          laboratoire: int.parse(state.pathParameters['id']!),
          titre: state.extra as String? ?? 'Laboratoire',
        ),
      ),
    ],
  );
});

class LabTrackApp extends ConsumerWidget {
  const LabTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LabTrack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeProvider),
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Ouverture du formulaire de modification sans fiche fournie (lien direct) : on charge d'abord l'équipement.
class _ChargerPuisModifier extends ConsumerWidget {
  const _ChargerPuisModifier({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(equipementProvider(id));
    return e.when(
      data: (equipement) => EquipementFormScreen(existant: equipement),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('Équipement introuvable'))),
    );
  }
}
