import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../theme/app_dimensions.dart';
import '../utils/environment_status.dart';
import 'environment_metric_card.dart';

/// ホーム画面中央の「各項目の状態」セクション。
/// 温度・湿度・土壌水分・照度を2×2のカードで表示する(要件定義書F-02)。
class PlantCard extends StatelessWidget {
  final Plant plant;

  const PlantCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.medium,
      crossAxisSpacing: AppSpacing.medium,
      childAspectRatio: 0.95,
      children: [
        EnvironmentMetricCard(
          label: '温度',
          valueText: '${plant.temperature}℃',
          icon: Icons.thermostat,
          iconColor: Colors.redAccent,
          status: temperatureStatus(plant.temperature),
        ),
        EnvironmentMetricCard(
          label: '湿度',
          valueText: '${plant.humidity}%',
          icon: Icons.water_drop,
          iconColor: Colors.blueAccent,
          status: humidityStatus(plant.humidity),
        ),
        EnvironmentMetricCard(
          label: '土壌水分',
          valueText: '${plant.soilMoisture}%',
          icon: Icons.eco,
          iconColor: Colors.green,
          status: soilMoistureStatus(plant.soilMoisture),
        ),
        EnvironmentMetricCard(
          label: '光量',
          valueText: '${plant.illuminance.toStringAsFixed(0)} lux',
          icon: Icons.wb_sunny,
          iconColor: Colors.orangeAccent,
          status: illuminanceStatus(plant.illuminance),
        ),
      ],
    );
  }
}
