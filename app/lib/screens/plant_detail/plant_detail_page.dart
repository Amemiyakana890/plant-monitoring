import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../theme/app_dimensions.dart';

class PlantDetailPage extends StatelessWidget {
  final Plant plant;

  const PlantDetailPage({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(plant.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 45,
              child: Icon(Icons.local_florist, size: 50),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('状態'),
              subtitle: Text(plant.status),
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
            child: const ListTile(
              leading: Icon(Icons.show_chart),
              title: Text('履歴グラフ'),
              subtitle: Text('今後実装予定'),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Card(
            child: const ListTile(
              leading: Icon(Icons.light_mode),
              title: Text('照度'),
              subtitle: Text('照度センサー接続後に表示'),
            ),
          ),
        ],
      ),
    );
  }
}
