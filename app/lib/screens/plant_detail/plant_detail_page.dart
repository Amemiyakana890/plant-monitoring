import 'package:flutter/material.dart';

import '../../models/plant.dart';
import '../../theme/app_colors.dart';

class PlantDetailPage extends StatelessWidget {
  final Plant plant;

  const PlantDetailPage({
    super.key,
    required this.plant,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(plant.name),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// 植物アイコン
          const Center(
            child: CircleAvatar(
              radius: 45,
              child: Icon(
                Icons.local_florist,
                size: 50,
              ),
            ),
          ),

          const SizedBox(height: 24),

          /// 現在の状態
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  const Text(
                    "現在の状態",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.thermostat),
                    title: const Text("温度"),
                    trailing: Text("${plant.temperature} ℃"),
                  ),

                  ListTile(
                    leading: const Icon(Icons.water_drop),
                    title: const Text("湿度"),
                    trailing: Text("${plant.humidity} %"),
                  ),

                  ListTile(
                    leading: const Icon(Icons.grass),
                    title: const Text("土壌水分"),
                    trailing: Text("${plant.soilMoisture} %"),
                  ),

                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// 状態
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text("状態"),
              subtitle: Text(plant.status),
            ),
          ),

          const SizedBox(height: 16),

          /// 更新時間
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text("最終更新"),
              subtitle: Text(plant.updatedAt),
            ),
          ),

          const SizedBox(height: 16),

          /// 今後追加予定
          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.show_chart),
              title: Text("履歴グラフ"),
              subtitle: Text("今後実装予定"),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.light_mode),
              title: Text("照度"),
              subtitle: Text("照度センサー接続後に表示"),
            ),
          ),

        ],
      ),
    );
  }
}
