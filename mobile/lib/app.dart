import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/connexion_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/equipements/detail_screen.dart';
import 'features/equipements/equipements_screen.dart';
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
      GoRoute(
        path: '/equipement/:id',
        builder: (_, state) => DetailEquipementScreen(id: int.parse(state.pathParameters['id']!)),
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
