import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../widgets/settings_app_bar.dart';

/// 設定画面上部のデバイスカードから遷移する、デバイス接続(ペアリング)画面。
///
/// TODO: 現状はUIのみで、設計書5-3のデバイスAPI(`GET /devices`,
/// `POST /devices/pair`等)には未接続(README進捗の「⬜デバイスペアリング機能の実装」に対応)。
/// API接続時は、スキャン結果を`GET /devices`、接続確定を`POST /devices/pair`に置き換えること。
class DeviceConnectionPage extends StatelessWidget {
  const DeviceConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'デバイス接続'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Text(
                  '接続中のデバイス',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.wifi),
                    title: const Text('Plant Monitor 01'),
                    subtitle: const Text('接続済み・バッテリー 85%'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.extraSmall),
                        const Text('オンライン'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  '近くのデバイスを探す',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('デバイスのスキャン（今後実装予定）')),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('スキャンする'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
