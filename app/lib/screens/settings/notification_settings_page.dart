import 'package:flutter/material.dart';

import '../../models/notification_settings.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// 通知設定画面(通知するアラートの種類を切り替える)。
///
/// 土壌水分・温度・湿度・照度のアラートは server/controllers/settingsController.js
/// (GET/PUT /settings/notification)経由でサーバーに保存され、実際の通知生成
/// (server/controllers/sensorController.js)にも反映される。トグルOFFは
/// 「通知の生成だけを止める」設計で、判定ロジックやホーム画面のバッジ表示には
/// 影響しない(docs/status-notification-design.md 6章、サイレントタイムと同じ
/// 「見守り自体は止めない」考え方)。
///
/// バッテリーアラートは今回のスコープ外。ESP32側にバッテリー残量を送信する
/// 仕組み自体がまだ無く実用化はまだ先のため、上記のAPIには含めていない。
/// このトグルだけは保存されないローカル状態のままなので、切り替えても
/// 実際の通知には影響しない(誤解を防ぐため、スイッチを無効化し注記を添えている)。
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // バッテリーアラートのみ、上記の理由でローカル状態のまま(未保存)。
  final bool _batteryAlert = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlantStoreScope.of(context).loadNotificationSettings();
    });
  }

  Future<void> _update(NotificationSettings updated) async {
    final store = PlantStoreScope.of(context);
    final ok = await store.updateNotificationSettings(updated);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知設定を保存できませんでした。もう一度お試しください')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final settings = store.notificationSettings;

    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: '通知設定'),
          Expanded(
            child: store.isLoadingNotificationSettings && settings == null
                ? const Center(child: CircularProgressIndicator())
                : settings == null
                ? Center(
                    child: Text(
                      store.notificationSettingsErrorMessage ??
                          '通知設定を取得できませんでした',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    children: [
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('土壌水分アラート'),
                              subtitle: const Text('土壌水分が少なくなった時に通知します'),
                              value: settings.soilAlertEnabled,
                              onChanged: (value) => _update(
                                settings.copyWith(soilAlertEnabled: value),
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('温度アラート'),
                              subtitle: const Text('温度が適正範囲から外れた時に通知します'),
                              value: settings.temperatureAlertEnabled,
                              onChanged: (value) => _update(
                                settings.copyWith(
                                  temperatureAlertEnabled: value,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            // 湿度・照度は1日1回(15:00)の日次評価で「要ケア」と
                            // 判定された場合のみ通知する(docs 3-2, 3-4, 6-5章)。
                            // 土壌水分・温度(リアルタイム評価)とは通知タイミングの
                            // 考え方が異なる点に注意。
                            SwitchListTile(
                              title: const Text('湿度アラート'),
                              subtitle: const Text(
                                '湿度が1日の平均で適正範囲から大きく外れた時に通知します',
                              ),
                              value: settings.humidityAlertEnabled,
                              onChanged: (value) => _update(
                                settings.copyWith(humidityAlertEnabled: value),
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('照度アラート'),
                              subtitle: const Text('日中の日照が1日の平均で不足している時に通知します'),
                              value: settings.illuminanceAlertEnabled,
                              onChanged: (value) => _update(
                                settings.copyWith(
                                  illuminanceAlertEnabled: value,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('バッテリーアラート'),
                              subtitle: const Text(
                                'デバイスのバッテリー残量が少なくなった時に通知します(準備中:ESP32側の'
                                'バッテリー残量送信が未実装のため、現在は通知されません)',
                              ),
                              value: _batteryAlert,
                              // 保存先が無いため無効化し、見た目だけのON/OFFで
                              // 実際の通知が来ると誤解されないようにしている。
                              onChanged: null,
                            ),
                          ],
                        ),
                      ),
                      if (store.notificationSettingsErrorMessage != null) ...[
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          store.notificationSettingsErrorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
