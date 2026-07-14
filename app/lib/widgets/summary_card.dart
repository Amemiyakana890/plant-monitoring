import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

class SummaryCard extends StatelessWidget {
  final String temperature;
  final String humidity;
  final String soilMoisture;

  const SummaryCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
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
          ],
        ),
      ),
    );
  }
}
