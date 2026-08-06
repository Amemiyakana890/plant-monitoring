import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../widgets/settings_app_bar.dart';

/// デバイス情報画面(バッテリー残量・ファームウェア等)。
///
/// TODO: 現状はUIのみで、設計書5-3の`GET /devices/:id`には未接続。
/// API接続時はこの画面に渡す値をレスポンス(battery_level/firmware_version等)に置き換えること。
class DeviceInfoPage extends StatelessWidget {
  const DeviceInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'デバイス情報'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: const [
                _InfoTile(label: 'デバイス名', value: 'Plant Monitor 01'),
                _InfoTile(label: '接続状態', value: '接続済み'),
                _InfoTile(label: 'バッテリー残量', value: '85%'),
                _InfoTile(label: 'ファームウェアバージョン', value: '1.0.2'),
                _InfoTile(label: 'MACアドレス', value: 'AA:BB:CC:DD:EE:FF'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
