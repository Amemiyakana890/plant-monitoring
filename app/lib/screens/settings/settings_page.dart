import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../state/plant_store_scope.dart';
import '../../state/theme_controller.dart';
import '../../state/theme_controller_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import 'app_info_page.dart';
import 'device_connection_page.dart';
import 'device_info_page.dart';
import 'notification_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // 上部カードに実際の接続状況を出すため、設定タブを開いたタイミングで
    // デバイス一覧を読み込んでおく。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlantStoreScope.of(context).loadDevices();
    });
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final store = PlantStoreScope.of(context);
    final linkedDeviceId = store.plant?.deviceId;

    Device? linkedDevice;
    if (linkedDeviceId != null) {
      final matches = store.devices.where((d) => d.id == linkedDeviceId);
      linkedDevice = matches.isEmpty ? null : matches.first;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('設定', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),

        // 上部:接続中デバイスのカード。タップでデバイス接続画面へ。
        // linkedDeviceがnullの場合(まだペアリングしていない)は案内文を出す。
        Card(
          color: AppColors.primary,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: () => _push(context, const DeviceConnectionPage()),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.wifi, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linkedDevice?.deviceName ?? 'デバイス未接続',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          linkedDevice != null
                              ? '接続済み・バッテリー ${linkedDevice.batteryLevel ?? '-'}%'
                              : 'タップしてデバイスを登録してください',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: linkedDevice != null
                              ? Colors.lightGreenAccent
                              : Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.extraSmall),
                      Text(
                        linkedDevice != null ? 'オンライン' : '未接続',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),

        // デバイス情報・通知設定
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.battery_full),
                title: const Text('デバイス情報'),
                subtitle: Text(
                  linkedDevice != null
                      ? 'バッテリー残量${linkedDevice.batteryLevel ?? '-'}%・ファームウェア ${linkedDevice.firmwareVersion ?? '-'}'
                      : 'デバイス未接続',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const DeviceInfoPage()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('通知設定'),
                subtitle: const Text('土壌水分・温度・バッテリーアラート'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const NotificationSettingsPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.medium),

        // テーマ切り替え(画面遷移なし。ライト/ダークをその場で切り替える)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Row(
              children: [
                const Icon(Icons.palette),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('テーマ'),
                      Text(
                        themeController.isDark ? 'ダークモード' : 'ライトモード',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _ThemeToggle(controller: themeController),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),

        // アプリ情報
        Card(
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text('アプリ情報'),
            subtitle: const Text('植物見守り・プライバシーポリシー・利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const AppInfoPage()),
          ),
        ),
        const SizedBox(height: AppSpacing.small),

        // バージョン(表示のみ、遷移なし)
        const Card(
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('バージョン'),
            subtitle: Text('Ver 1.0.0（ビルド 20260804.1）'),
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
    );
  }
}

/// 「ライト / ダーク」の2択セグメントボタン。
class _ThemeToggle extends StatelessWidget {
  final ThemeController controller;

  const _ThemeToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeToggleButton(
            label: 'ライト',
            icon: Icons.wb_sunny,
            selected: !controller.isDark,
            onTap: controller.setLight,
          ),
          _ThemeToggleButton(
            label: 'ダーク',
            icon: Icons.nightlight_round,
            selected: controller.isDark,
            onTap: controller.setDark,
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
