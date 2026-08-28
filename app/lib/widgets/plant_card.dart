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
/// はみ出す(オーバーフロー)おそれが出てきた。そのため、いったんは
/// `IntrinsicHeight`付きの`Row`2本で高さを強制的に揃える形にしていたが、
/// Flutter Web環境でNoto Sans JPフォントの読み込みが完了する前の初回描画時
/// (フォールバックフォントでの仮の文字寸法)と、フォント読み込み後の再描画
/// (正しい文字寸法)とで`IntrinsicHeight`の事前測定結果がわずかにズレ、
/// 「初回表示時だけ数px溢れる、画面遷移すると直る」というオーバーフローが
/// 発生していた。`IntrinsicHeight`自体がこの種の食い違いに弱いため、
/// 高さを強制的に揃えるのをやめ、各カードが自分の中身に応じて自然に
/// 高さを決める(揃わなくてもよしとする)形に変更している。
class PlantCard extends StatelessWidget {
  final Plant plant;

  const PlantCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: AppSpacing.medium),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        SnackBar(content: Text(store.wateringErrorMessage ?? '水やりの記録に失敗しました')),
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
          // カード幅が狭い(半分幅)ため、長い表示文字列(例:「まだ記録が
          // ありません」)でもはみ出さないよう、1行に収めて省略表示にする。
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.extraSmall),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: store.isRecordingWatering
                ? null
                : () => _handleTap(context),
            style: OutlinedButton.styleFrom(
              // デフォルトの横パディングだと、半分幅のカードでは
              // アイコン+ラベルがRenderFlexオーバーフローしていたため
              // (「A RenderFlex overflowed by 27 pixels on the right.」)、
              // 横パディングを詰めている。
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              visualDensity: VisualDensity.compact,
              minimumSize: Size.zero,
            ),
            // OutlinedButton.icon(icon:, label:)は内部のRowをこちらで
            // カスタマイズできず、ラベルが長い/カードが狭い環境でオーバー
            // フローする恐れがあったため、Flexible + ellipsisで確実に
            // 収まるRowを自前で組んでいる(万一入り切らない場合も、
            // エラーにはならず文字が「…」で省略されるだけになる)。
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                store.isRecordingWatering
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.water_drop, size: 14),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    '水やり',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
