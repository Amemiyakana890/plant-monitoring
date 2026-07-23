import 'package:flutter/material.dart';

import '../../data/dummy_plants.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/home_plant_card.dart';
import '../plant_detail/plant_detail_page.dart';

/// 複数植物を一覧・管理する画面。
///
/// 現行v1は1台のデバイス・1株のみを管理する単独構成のため
/// (要件定義書9章)、この画面はまだボトムナビゲーションからは
/// 遷移できない。企画書11章「複数植物・複数デバイスへの対応強化」に
/// 向けたv2実装の下書きとして残している。
class PlantsPage extends StatelessWidget {
  const PlantsPage({super.key});

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
          onPressed: () => _showComingSoon(context, '植物追加画面（今後実装予定）'),
        ),
        const SizedBox(height: AppSpacing.large),
        ...dummyPlantsList.map(
          (plant) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: HomePlantCard(
              plant: plant,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlantDetailPage(plant: plant),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
