import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// 設定配下のサブ画面(デバイス接続・デバイス情報・通知設定・アプリ情報等)で
/// 共通して使うAppBar。
///
/// アプリ全体の標準AppBar(緑背景+白字、`app_theme.dart`の`appBarTheme`)とは
/// あえて分け、設定サブ画面では背景色に馴染む白丸の戻るボタン+太字タイトルに
/// 統一する(アプリ情報画面のデザイン画像に合わせたスタイル)。
///
/// ただしステータスバー(端末最上部の時計・電池残量などが並ぶ帯)は、
/// アプリ全体で緑(AppColors.primary)に統一したいというデザイン意図があるため、
/// AppBar自体の背景色(ここでは薄い背景色)とは別に`systemOverlayStyle`で
/// ステータスバーの色だけ明示的に緑へ固定している。
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const SettingsAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 56,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light, // Android:アイコンを白系に
        statusBarBrightness: Brightness.dark, // iOS:アイコンを白系に
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.chevron_left, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
