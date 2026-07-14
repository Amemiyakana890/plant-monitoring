import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

class PlantCard extends StatelessWidget {
  final String name;
  final String temperature;
  final String humidity;
  final String soilMoisture;
  final String status;
  final String updatedAt;
  final IconData icon;

  const PlantCard({
    super.key,
    required this.name,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.status,
    required this.updatedAt,
    this.icon = Icons.local_florist,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.extraSmall),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text('🌡 温度　$temperature'),
            Text('💧 湿度　$humidity'),
            Text('🪴 土壌水分　$soilMoisture'),
            const SizedBox(height: AppSpacing.small),
            Text('状態：$status'),
            const Divider(),
            Text(
              '最終更新：$updatedAt',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
