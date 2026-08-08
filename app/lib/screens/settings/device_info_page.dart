import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/settings_app_bar.dart';
import 'device_connection_page.dart';

/// デバイス情報画面(バッテリー残量・ファームウェア等)。
///
/// 現在の植物(PlantStore.plant)に紐付いているdeviceIdをもとに
/// GET /devices/:id相当のデータを取得して表示する(設計書5-3)。
/// 紐付いているデバイスが無い場合は、デバイス接続画面への導線を表示する。
class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  Device? _device;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final deviceId = PlantStoreScope.of(context).plant?.deviceId;
    if (deviceId == null) {
      setState(() {
        _isLoading = false;
        _device = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // PlantStoreはリスト(devices)しか公開していないため、単発取得は
      // リポジトリを直接使わず、既に読み込み済みのdevicesから探す形にする。
      final store = PlantStoreScope.of(context);
      if (store.devices.isEmpty) {
        await store.loadDevices();
      }
      final matches = store.devices.where((d) => d.id == deviceId);
      setState(() => _device = matches.isEmpty ? null : matches.first);
    } catch (_) {
      setState(() => _errorMessage = 'デバイス情報を取得できませんでした');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SettingsAppBar(title: 'デバイス情報'),
          Expanded(child: _buildBody(context)),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    final device = _device;
    if (device == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          const Text('まだデバイスが紐付けられていません。'),
          const SizedBox(height: AppSpacing.medium),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeviceConnectionPage()),
            ),
            icon: const Icon(Icons.wifi),
            label: const Text('デバイス接続画面へ'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        // ESP32側の DEVICE_ID 定数と見比べられるよう、先頭にIDを表示する。
        // ペアリング解除→再登録すると、サーバー側で新しい連番IDが振られ、
        // ESP32側のDEVICE_IDが古いままだと404で繋がらなくなるため
        // (device-test-log01.md 2026-08-07参照)、ここで確認できるようにしている。
        _InfoTile(label: 'デバイスID', value: '${device.id}'),
        _InfoTile(label: 'デバイス名', value: device.deviceName),
        _InfoTile(label: '接続状態', value: device.isConnected ? '接続済み' : '未接続'),
        _InfoTile(
          label: 'バッテリー残量',
          value: device.batteryLevel != null ? '${device.batteryLevel}%' : '-',
        ),
        _InfoTile(
          label: 'ファームウェアバージョン',
          value: device.firmwareVersion ?? '-',
        ),
        _InfoTile(label: 'MACアドレス', value: device.macAddress),
      ],
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
