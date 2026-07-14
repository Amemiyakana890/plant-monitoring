import 'package:flutter/material.dart';

import '../../data/dummy_plants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

class PlantsPage extends StatelessWidget {
  const PlantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('植物管理', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('植物を追加'),
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('植物追加画面（今後実装予定）')));
          },
        ),
        const SizedBox(height: AppSpacing.large),
        ...dummyPlants.map(
          (plant) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.medium),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_florist,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.extraSmall),
                        Text(
                          plant.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.extraSmall),
                    Text('センサーID : ATOM-00${plant.id}'),
                    const SizedBox(height: AppSpacing.medium),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('編集'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${plant.name} 編集（今後実装予定）'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.small),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text('削除'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${plant.name} 削除（今後実装予定）'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
