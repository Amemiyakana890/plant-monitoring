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
        // ①一番上:植物名・全体の様子
        StatusHeroCard(plant: plant),
        const SizedBox(height: AppSpacing.medium),
        // ②真ん中:各項目(温度・湿度・土壌水分・照度)の状態
        PlantCard(plant: plant),
        const SizedBox(height: AppSpacing.medium),
        // ③一番下:今日のまとめ
        // v1は1株のみの構成のため「今日のまとめ」＝その1株の実測値。
        // 複数植物対応時はストア側で全植物の平均値を計算する想定(要件定義書F-02)。
        SummaryCard(
          temperature: '${plant.temperature}℃',
          humidity: '${plant.humidity}%',
          soilMoisture: '${plant.soilMoisture}%',
        ),
      ],
    );
  }
}
