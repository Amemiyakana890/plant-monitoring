import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            "設定",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.notifications),
              title: Text("通知設定"),
              subtitle: Text("通知のON/OFFを設定します"),
              trailing: Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.palette),
              title: Text("テーマ"),
              subtitle: Text("ライトモード"),
              trailing: Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.info),
              title: Text("アプリ情報"),
              subtitle: Text("植物見守りアプリ"),
              trailing: Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(Icons.code),
              title: Text("バージョン"),
              subtitle: Text("Ver 1.0.0"),
            ),
          ),
        ],
      ),
    );
  }
}
