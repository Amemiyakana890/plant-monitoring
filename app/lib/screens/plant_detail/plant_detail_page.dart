import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../theme/app_dimensions.dart';
import '../../utils/plant_status.dart';
import '../history/history_page.dart';

/// [PlantsPage](複数植物一覧、v2向け下書き)から遷移する、1株分の詳細画面。
/// 状態の表現は[StatusHeroCard]と同じ[plantStatusInfo]を使い、
/// アイコン・色・メッセージを画面間で統一している。
class PlantDetailPage extends StatelessWidget {
  final Plant plant;

  const PlantDetailPage({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final info = plantStatusInfo[plant.status]!;

    return Scaffold(
      appBar: AppBar(title: Text(plant.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: info.color.withValues(alpha: 0.12),
              child: Icon(info.icon, size: 50, color: info.color),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Center(
            child: Text(
              info.message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: info.color),
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                children: [
                  Text('現在の状態', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.thermostat),
                    title: const Text('温度'),
                    trailing: Text('${plant.temperature} ℃'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.water_drop),
                    title: const Text('湿度'),
                    trailing: Text('${plant.humidity} %'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.grass),
                    title: const Text('土壌水分'),
                    trailing: Text('${plant.soilMoisture} %'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.light_mode),
                    title: const Text('照度'),
                    trailing: Text('${plant.illuminance} lx'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('最終更新'),
              subtitle: Text(plant.updatedAt),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('履歴グラフ'),
              subtitle: const Text('環境データの推移を確認できます'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('履歴')),
                      body: const HistoryPage(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
