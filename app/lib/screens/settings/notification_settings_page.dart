import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// 通知設定画面(通知するアラートの種類を切り替える)。
///
/// TODO: 現状は画面内のローカル状態のみで、設計書6章の
/// `notification_settings`テーブル(frequency/start_time/end_time/sound_enabled)
/// やAPI(`GET/PUT /settings/notification`)にはまだ接続していない。
/// アラート種別ごとのON/OFFを保存する仕組みは現行のテーブル定義に無いため、
/// API/DB側の項目追加も合わせて検討すること。
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _soilAlert = true;
  bool _temperatureAlert = true;
  bool _batteryAlert = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: '通知設定'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('土壌水分アラート'),
                        subtitle: const Text('土壌水分が少なくなった時に通知します'),
                        value: _soilAlert,
                        onChanged: (value) =>
                            setState(() => _soilAlert = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('温度アラート'),
                        subtitle: const Text('温度が適正範囲から外れた時に通知します'),
                        value: _temperatureAlert,
                        onChanged: (value) =>
                            setState(() => _temperatureAlert = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('バッテリーアラート'),
                        subtitle: const Text('デバイスのバッテリー残量が少なくなった時に通知します'),
                        value: _batteryAlert,
                        onChanged: (value) =>
                            setState(() => _batteryAlert = value),
                      ),
                    ],
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
