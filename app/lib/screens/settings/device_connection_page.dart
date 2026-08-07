import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';

/// 設定画面上部のデバイスカードから遷移する、デバイス接続(ペアリング)画面。
///
/// 実機のBLE/Wi-Fiスキャンにはまだ対応していないため、「スキャンする」の
/// 代わりにデバイス名・MACアドレスを手入力してペアリングする方式にしている
/// (README進捗の「デバイスペアリング機能の実装」のうち、DB/API/紐付け部分に対応。
/// 実機スキャンへの置き換えは別途検討)。
class DeviceConnectionPage extends StatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> {
  @override
  void initState() {
    super.initState();
    // 画面表示時に最新のデバイス一覧を取得する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlantStoreScope.of(context).loadDevices();
    });
  }

  Future<void> _showPairDialog() async {
    final nameController = TextEditingController(text: 'Plant Monitor 01');
    final macController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: const Text('デバイスを登録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '実機スキャンは未対応のため、デバイス名とMACアドレスを入力してください。',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.medium),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'デバイス名'),
              ),
              const SizedBox(height: AppSpacing.small),
              TextField(
                controller: macController,
                decoration: const InputDecoration(
                  labelText: 'MACアドレス',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('登録する'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) return;

    final store = PlantStoreScope.of(context);
    final success = await store.pairAndLinkDevice(
      deviceName: nameController.text.trim(),
      macAddress: macController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'デバイスを登録しました' : (store.pairErrorMessage ?? '登録に失敗しました'),
        ),
      ),
    );
  }

  Future<void> _confirmUnpair(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('ペアリング解除'),
        content: Text('「${device.deviceName}」のペアリングを解除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final store = PlantStoreScope.of(context);
    final success = await store.unpairDevice(device.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'ペアリングを解除しました' : (store.pairErrorMessage ?? '解除に失敗しました'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final linkedDeviceId = store.plant?.deviceId;

    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'デバイス接続'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: store.loadDevices,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(
                    '登録済みのデバイス',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  if (store.isLoadingDevices)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.large,
                      ),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (store.devicesErrorMessage != null)
                    Text(
                      store.devicesErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (store.devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.medium,
                      ),
                      child: Text('登録済みのデバイスはありません'),
                    )
                  else
                    ...store.devices.map(
                      (device) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.wifi),
                          title: Text(
                            device.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            device.id == linkedDeviceId
                                ? 'この植物に接続済み・バッテリー ${device.batteryLevel ?? '-'}%'
                                : '未接続(他の植物用、またはペアリングのみ完了)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.link_off),
                            tooltip: 'ペアリング解除',
                            onPressed: () => _confirmUnpair(device),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'デバイスを登録する',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  OutlinedButton.icon(
                    onPressed: store.isPairing ? null : _showPairDialog,
                    icon: store.isPairing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_link),
                    label: const Text('デバイスを登録する'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
