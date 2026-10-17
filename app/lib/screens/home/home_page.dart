import 'package:flutter/material.dart';

import '../../state/plant_store_scope.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/plant_card.dart';
import '../../widgets/status_hero_card.dart';
import '../../widgets/summary_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final plant = store.plant;

    if (store.isLoadingPlant && plant == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plant == null) {
      return Center(child: Text(store.errorMessage ?? '植物の情報がありません'));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        StatusHeroCard(plant: plant),
        const SizedBox(height: AppSpacing.large),
        const _HomeSectionHeading(),
        const SizedBox(height: AppSpacing.small),
        PlantCard(plant: plant),
        const SizedBox(height: AppSpacing.large),
        // v1は1株のみの構成のため「今日のまとめ」＝その1株の実測値。
        // 複数植物対応時はストア側で全植物の平均値を計算する想定(要件定義書F-02)。
        SummaryCard(
          temperature: '${plant.temperature}℃',
          humidity: '${plant.humidity}%',
          soilMoisture: '${plant.soilMoisture}%',
          illuminance: '${plant.illuminance.toStringAsFixed(0)} lux',
        ),
      ],
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE ENVIRONMENT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF718B5D),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text('現在の環境', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF789B60)),
              SizedBox(width: 6),
              Text(
                'リアルタイム',
                style: TextStyle(
                  color: Color(0xFF718B5D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
