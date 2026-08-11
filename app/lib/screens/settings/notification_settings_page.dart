import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// 通知設定画面(通知するアラートの種類を切り替える)。
///
/// TODO: 現状は画面内のローカル状態のみで、設計書6章の
/// `notification_settings`テーブル(frequency/start_time/end_time/sound_enabled)
/// やAPI(`GET/PUT /settings/notification`)にはまだ接続していない
/// (このページを閉じると設定は保存されず、スイッチの状態は実際の通知生成にも
/// 一切影響しない)。今後バックエンドに接続する際は、以下も合わせて対応する:
///   1. `notification_settings`にアラート種別ごとのON/OFF列を追加
///      (現行スキーマにはfrequency/start_time/end_time/sound_enabledしかなく、
///      種別ごとのON/OFF列がまだない)
///   2. `GET/PUT /settings/notification` APIの実装
///   3. このページをAPIに接続(保存・読み込み)
///   4. サーバー側の通知生成ロジック(server/controllers/sensorController.js)で、
///      通知を作る前に該当設定がONかどうかをチェックする処理を追加
///   5. サイレントタイム(20:00〜06:00は通知を保留する仕組み、
///      docs/status-notification-design.md 6-4章)も未実装のため、
///      上記と合わせて対応時期を改めて検討する
/// バッテリーアラートについては、そもそもバッテリー残量を送信する仕組み自体が
/// ESP32側にまだ無い(server/controllers/sensorController.js参照)ため、
/// このトグル自体が実装待ちの機能に対する先行UIである点に注意。
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _soilAlert = true;
  bool _temperatureAlert = true;
  bool _humidityAlert = true;
  bool _illuminanceAlert = true;
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
                      // 湿度・照度は1日1回(15:00)の日次評価で「要ケア」と
                      // 判定された場合のみ通知する(docs/status-notification-design.md
                      // 3-2, 3-4, 6-5章)。土壌水分・温度(リアルタイム評価)とは
                      // 通知タイミングの考え方が異なる点に注意。
                      SwitchListTile(
                        title: const Text('湿度アラート'),
                        subtitle: const Text('湿度が1日の平均で適正範囲から大きく外れた時に通知します'),
                        value: _humidityAlert,
                        onChanged: (value) =>
                            setState(() => _humidityAlert = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('照度アラート'),
                        subtitle: const Text('日中の日照が1日の平均で不足している時に通知します'),
                        value: _illuminanceAlert,
                        onChanged: (value) =>
                            setState(() => _illuminanceAlert = value),
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
