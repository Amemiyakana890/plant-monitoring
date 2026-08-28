import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// アプリ情報画面。
///
/// 「アプリについて」の説明文と、プライバシーポリシー・利用規約・
/// オープンソースライセンス・サポートへの問い合わせの4項目で構成する。
/// 各項目の詳細な内容(実際の文章・問い合わせ手段など)は今後追記する想定のため、
/// 現時点ではタップ時に「今後実装予定」を表示するのみ。
class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label（今後実装予定）')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'アプリ情報'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                const SizedBox(height: AppSpacing.small),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Center(
                  child: Text(
                    '植物見守り',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'バージョン 1.0.0',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),

                // アプリについて
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'アプリについて',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          '植物見守りは、センサーデバイスを使って植物の環境'
                          '(温度・湿度・土壌水分・光量)をリアルタイムで監視するアプリです。'
                          'アラート機能で水やりのタイミングを見逃しません。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),

                // プライバシーポリシー・利用規約・オープンソースライセンス・サポート
                Card(
                  child: Column(
                    children: [
                      _AppInfoTile(
                        icon: Icons.lock,
                        iconBackground: AppColors.warning,
                        title: 'プライバシーポリシー',
                        onTap: () => _showComingSoon(context, 'プライバシーポリシー'),
                      ),
                      const Divider(height: 1),
                      _AppInfoTile(
                        icon: Icons.description,
                        iconBackground: AppColors.info,
                        title: '利用規約',
                        onTap: () => _showComingSoon(context, '利用規約'),
                      ),
                      const Divider(height: 1),
                      _AppInfoTile(
                        icon: Icons.balance,
                        iconBackground: AppColors.accent,
                        title: 'オープンソースライセンス',
                        onTap: () => _showComingSoon(context, 'オープンソースライセンス'),
                      ),
                      const Divider(height: 1),
                      _AppInfoTile(
                        icon: Icons.chat_bubble,
                        iconBackground: AppColors.secondary,
                        title: 'サポートに問い合わせ',
                        onTap: () => _showComingSoon(context, 'サポートに問い合わせ'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),

                Center(
                  child: Text(
                    '植物見守り © 2026',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class _AppInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final String title;
  final VoidCallback onTap;

  const _AppInfoTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBackground.withValues(alpha: 0.18),
        child: Icon(icon, color: iconBackground, size: 20),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
