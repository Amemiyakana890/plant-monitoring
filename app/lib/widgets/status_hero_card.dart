import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_dimensions.dart';
import '../utils/plant_status.dart';

/// 「静かに見守る」コンセプトに沿って、状態(アイコン+短いメッセージ)を
/// 数値より優先して大きく表示するカード。
class StatusHeroCard extends StatelessWidget {
  final Plant plant;

  const StatusHeroCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final info = plantStatusInfo[plant.status]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          children: [
            Icon(info.icon, size: 56, color: info.color),
            const SizedBox(height: AppSpacing.small),
            Text(plant.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.extraSmall),
            Text(
              info.message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: info.color),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              '最終更新：${plant.updatedAtDisplay}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
