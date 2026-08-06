import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// 設定配下のサブ画面(デバイス接続・デバイス情報・通知設定・アプリ情報等)で
/// 共通して使うヘッダー。`Scaffold`の`appBar:`ではなく`body:`側のColumnの
/// 先頭要素として配置する(使い方は各ページの実装を参照)。
///
/// 見た目は「上段:緑の帯」「下段:薄い背景色+丸い戻るボタン+太字タイトル」の
/// 2段構成(デザイン画像に合わせたスタイル)。
///
/// 緑の帯の高さは`SafeArea`の`minimum`で
/// 「実機のノッチ/ステータスバー分の高さ」と「最低28px」の大きい方を採用する。
/// これにより、ノッチのある実機では帯がノッチ分まで自動で伸び、
/// ノッチが存在しないWeb/デスクトップのプレビューでも28px分の帯が
/// 必ず表示される(OSのステータスバー機能そのものには依存しない)。
class SettingsAppBar extends StatelessWidget {
  final String title;

  static const double _minGreenBarHeight = 28;

  const SettingsAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ダークモードでも視認できるよう、固定の濃いグレー(AppColors.textPrimary)
    // ではなく、テーマのテキスト色(ライト:濃いグレー/ダーク:白)を使う。
    final onBackgroundColor = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: _minGreenBarHeight),
        child: Container(
          color: theme.scaffoldBackgroundColor,
          height: kToolbarHeight,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Material(
                  // 戻るボタンの丸背景は白丸のまま統一(ライト/ダーク共通)にし、
                  // 中のアイコンは常に濃色にすることで、どちらのテーマでも
                  // コントラストを確保する(白背景+濃色アイコンで固定)。
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onBackgroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
