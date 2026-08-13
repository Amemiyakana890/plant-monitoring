import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../utils/environment_status.dart';

/// ホーム画面中央に並ぶ、温度・湿度・土壌水分・照度それぞれのカード。
/// アイコン・数値・プログレスバー・状態タグ(適正/注意)を1枚にまとめる。
class EnvironmentMetricCard extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final Color iconColor;
  final EnvironmentStatus status;

  /// 湿度・照度のように「バッジは日次評価、数値はリアルタイム」という
  /// 見せ方(docs/status-notification-design.md 3-6章)をしているカードで、
  /// バッジの下に評価時刻を小さく添えるためのキャプション。
  /// 温度・土壌水分のようにリアルタイム評価のカードではnull(非表示)にする。
  final String? statusCaption;

  /// カード下部に追加コンテンツを差し込むための拡張スロット。
  /// 現状は土壌水分カードの「水やりした」ボタン+最終水やり表示
  /// (widgets/plant_card.dart, docs 4-2章)でのみ使用する。
  /// null(他3項目)の場合は何も表示せず、これまで通りの見た目のまま。
  final Widget? footer;

  const EnvironmentMetricCard({
    super.key,
    required this.label,
    required this.valueText,
    required this.icon,
    required this.iconColor,
    required this.status,
    this.statusCaption,
    this.footer,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Icon(icon, color: iconColor),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              valueText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.extraSmall),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: LinearProgressIndicator(
                value: status.ratio,
                minHeight: 6,
                color: status.color,
                backgroundColor: status.color.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (statusCaption != null && statusCaption!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                statusCaption!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.small),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
