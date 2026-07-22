import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label（今後実装予定）')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('設定', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('デバイス接続'),
            subtitle: const Text('Plant Monitor 01・接続済み'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'デバイス接続'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Card(
          child: ListTile(
            leading: const Icon(Icons.battery_full),
            title: const Text('デバイス情報'),
            subtitle: const Text('バッテリー残量85%・ファームウェア 1.0.2'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'デバイス情報'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知設定'),
            subtitle: const Text('通知のON/OFFを設定します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, '通知設定'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('テーマ'),
            subtitle: const Text('ライトモード'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'テーマ'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text('アプリ情報'),
            subtitle: const Text('植物見守りアプリ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'アプリ情報'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Card(
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('バージョン'),
            subtitle: Text('Ver 1.0.0'),
          ),
        ),
      ],
    );
  }
}
