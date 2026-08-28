import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// ホーム画面の「今日のまとめ」表示(要件定義書 F-02)。
/// v1は1株のみの構成のため、渡される値は現状その1株の実測値だが、
/// 複数植物対応時はここに平均値を渡す想定。
class SummaryCard extends StatelessWidget {
  final String temperature;
  final String humidity;
  final String soilMoisture;
  final String illuminance;

  const SummaryCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.extraSmall),
                Text('今日のまとめ', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('🌡 平均温度'), Text(temperature)],
            ),
            const SizedBox(height: AppSpacing.extraSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('💧 平均湿度'), Text(humidity)],
            ),
            const SizedBox(height: AppSpacing.extraSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('🪴 平均土壌水分'), Text(soilMoisture)],
            ),
            const SizedBox(height: AppSpacing.extraSmall),
            // 履歴画面・環境データカード(plant_card.dart)と表記を揃え、
            // 「照度」ではなく「光量」とする。
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('☀️ 平均光量'), Text(illuminance)],
            ),
          ],
        ),
      ),
    );
  }
}
