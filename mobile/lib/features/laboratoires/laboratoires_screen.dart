import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/composants.dart';
import '../auth/auth_controller.dart';
import '../equipements/equipements_repository.dart';
import 'labo_actions.dart';
import 'labo_card.dart';

/// Laboratoires : des cartes en dégradé, une couleur par laboratoire. L'administrateur peut en créer ;
/// la suppression se fait depuis la page d'un laboratoire (menu « ⋮ »).
class LaboratoiresScreen extends ConsumerWidget {
  const LaboratoiresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labos = ref.watch(laboratoiresProvider);
    final admin = ref.watch(utilisateurProvider)?.estAdmin ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(laboratoiresProvider);
          ref.invalidate(statistiquesProvider);
        },
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Laboratoires', style: context.text.headlineMedium),
                            const SizedBox(height: 2),
                            Text(
                              labos.hasValue
                                  ? '${labos.value!.length} laboratoire${labos.value!.length > 1 ? 's' : ''}'
                                  : 'Répartition du matériel',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (admin)
                        Pressable(
                          onTap: () => ouvrirFormulaireLabo(context),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(14)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Nouveau',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ...labos.when(
              data: (liste) => liste.isEmpty
                  ? [
                      SliverSafeArea(
                        top: false,
                        sliver: SliverFillRemaining(
                          hasScrollBody: false,
                          child: EtatVide(
                            icone: Icons.science_outlined,
                            titre: 'Aucun laboratoire',
                            message: admin
                                ? 'Créez le premier laboratoire pour commencer à y ranger du matériel.'
                                : 'L\'administrateur doit d\'abord en créer.',
                            action: admin ? 'Créer un laboratoire' : null,
                            onAction: admin ? () => ouvrirFormulaireLabo(context) : null,
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: .94,
                          ),
                          itemCount: liste.length,
                          itemBuilder: (_, i) => Entree(index: i ~/ 2, child: LaboCard(liste[i])),
                        ),
                      ),
                    ],
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .94,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, _) => const Skeleton(height: double.infinity, radius: 28),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverSafeArea(
                  top: false,
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: EtatVide(
                      icone: Icons.cloud_off_rounded,
                      titre: 'Chargement impossible',
                      message: messageErreur(e),
                      action: 'Réessayer',
                      couleur: Palette.rose,
                      onAction: () => ref.invalidate(laboratoiresProvider),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}
