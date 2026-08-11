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
          // 温度はリアルタイム・継続時間ベースのサーバー判定を使う
          // (docs/status-notification-design.md 3-1章)。
          status: environmentStatusFromLevel(
            plant.tempStatus,
            ratio: temperatureRatio(plant.temperature),
          ),
        ),
        EnvironmentMetricCard(
          label: '湿度',
          valueText: '${plant.humidity}%',
          icon: Icons.water_drop,
          iconColor: Colors.blueAccent,
          // 湿度は1日1回(15:00)の日次評価(24時間平均)を使う「日次レポート型」
          // (docs 3-2, 3-6章)。数値はリアルタイム値のまま、バッジだけ
          // 直近の日次評価結果を表示し、評価時刻をキャプションで補足する。
          status: environmentStatusFromLevel(
            plant.humidityDailyStatus,
            ratio: humidityRatio(plant.humidity),
          ),
          statusCaption: plant.humidityEvaluatedAtDisplay,
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
          // 照度も湿度と同じく日次レポート型(昼間6:00〜18:00の平均、docs 3-4, 3-6章)。
          status: environmentStatusFromLevel(
            plant.illuminanceDailyStatus,
            ratio: illuminanceRatio(plant.illuminance),
          ),
          statusCaption: plant.illuminanceEvaluatedAtDisplay,
        ),
      ],
    );
  }
}
