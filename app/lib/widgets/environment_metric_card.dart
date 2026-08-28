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
                // カード幅が狭い(半分幅・狭いブラウザ幅など)環境で、
                // ラベル(例:「土壌水分」)+アイコンがRenderFlowオーバーフロー
                // していたため、_WateringFooterの「水やり」ボタンと同じ対処
                // (Flexible + ellipsis)を入れて、入り切らない場合は確実に
                // 省略表示になるようにしている。
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                backgroundColor: status.color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
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
            // キャプション欄は「表示する/しない」で高さを動的に変えず、
            // 常に同じ高さを確保しておく(中身が空文字でもSizedBoxだけ描画する)。
            //
            // 経緯: 以前はstatusCaptionの有無でこの部分の高さ自体が変わって
            // いたため、同じ行に並ぶ温度カード(キャプション無し)と湿度カード
            // (キャプション有り)の高さがタイミングによって食い違い、
            // IntrinsicHeightでの高さ合わせ(widgets/plant_card.dart)がズレて
            // 「BOTTOM OVERFLOWED BY 2.0 PIXELS」が発生することがあった
            // (日次評価が実行されてキャプションが付く/消えるタイミングで
            // 再現するため、「時間が経つと直ったり再現したりする」ように見えていた)。
            // 高さを固定することで、この食い違い自体をそもそも起こさないようにしている。
            const SizedBox(height: 2),
            SizedBox(
              height: 14,
              child: (statusCaption != null && statusCaption!.isNotEmpty)
                  ? Text(
                      statusCaption!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.grey),
                    )
                  : null,
            ),
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
