import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../state/plant_store.dart';
import '../state/plant_store_scope.dart';
import '../theme/app_dimensions.dart';
import '../utils/environment_status.dart';
import 'environment_metric_card.dart';

/// ホーム画面中央の「各項目の状態」セクション。
/// 温度・湿度・土壌水分・照度を2×2のカードで表示する(要件定義書F-02)。
///
/// 以前は`GridView.count`で4枚を均等なマス目に並べていたが、土壌水分カードに
/// 「水やりした」ボタン(docs/status-notification-design.md 4-2章)を追加した
/// ことで土壌水分だけ縦に長くなり、固定サイズのグリッドでは中身が
/// はみ出す(オーバーフロー)おそれが出てきた。そのため、2行×2列を
/// `IntrinsicHeight`付きの`Row`2本で組む形に変更している。これにより
/// 「土壌水分・光量」の行は「温度・湿度」の行と独立して、その行の中で
/// 一番背の高いカード(=土壌水分)に他方(照度)の高さを合わせる形になる。
class PlantCard extends StatelessWidget {
  final Plant plant;

  const PlantCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: EnvironmentMetricCard(
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
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: EnvironmentMetricCard(
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
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: EnvironmentMetricCard(
                  label: '土壌水分',
                  valueText: '${plant.soilMoisture}%',
                  icon: Icons.eco,
                  iconColor: Colors.green,
                  status: soilMoistureStatus(plant.soilMoisture),
                  footer: _WateringFooter(plant: plant, store: store),
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: EnvironmentMetricCard(
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 土壌水分カードの下部に表示する「最終水やり」表示 + 記録ボタン
/// (docs/status-notification-design.md 4-2章)。
///
/// 履歴一覧・グラフへの反映は保留し(4-2章参照)、v1では「最後にいつ
/// 水をあげたか」を記録・表示できれば十分という判断でシンプルにしている。
class _WateringFooter extends StatelessWidget {
  final Plant plant;
  final PlantStore store;

  const _WateringFooter({required this.plant, required this.store});

  Future<void> _handleTap(BuildContext context) async {
    final ok = await store.recordWatering();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(store.wateringErrorMessage ?? '水やりの記録に失敗しました'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最終水やり: ${plant.lastWateredAtDisplay()}',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.extraSmall),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: store.isRecordingWatering
                ? null
                : () => _handleTap(context),
            icon: store.isRecordingWatering
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.water_drop, size: 16),
            label: const Text('水やりした'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
