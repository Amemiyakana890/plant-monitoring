import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('設定', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知設定'),
            subtitle: Text('通知のON/OFFを設定します'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Card(
          child: ListTile(
            leading: Icon(Icons.palette),
            title: Text('テーマ'),
            subtitle: Text('ライトモード'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info),
            title: Text('アプリ情報'),
            subtitle: Text('植物見守りアプリ'),
            trailing: Icon(Icons.chevron_right),
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
