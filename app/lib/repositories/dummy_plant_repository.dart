import 'dart:math';

import '../data/dummy_plants.dart';
import '../models/device.dart';
import '../models/environment_log.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';
import 'plant_repository.dart';

/// [PlantRepository]のダミー実装。
///
/// サーバー(Node.js + SQLite)が用意できるまでの間、画面側は本実装を
/// 経由して開発・確認を進める。実サーバーができたら`HttpPlantRepository`を
/// 新設して[PlantRepository]を実装し、[PlantStore]の生成箇所
/// (main.dart)で差し替えるだけで、画面側のコードは変更不要になる想定。
///
/// ダミーデータ(dummy_plants.dart)を直接importしているのはこのファイルだけ。
/// 画面側は必ず[PlantStore]経由でデータを取得する。
class DummyPlantRepository implements PlantRepository {
  Plant _plant = dummyPlant;

  // 実サーバー同様、ペアリング済みデバイスは正の連番idを払い出す。
  int _nextDeviceId = 1;
  final List<Device> _devices = [];

  final List<PlantNotification> _notifications = [
    const PlantNotification(
      id: 1,
      plantId: 1,
      message: '土壌水分が少なくなっています',
      isRead: false,
      createdAt: '7/8 10:30',
    ),
    const PlantNotification(
      id: 2,
      plantId: 1,
      message: '室温が30℃を超えました',
      isRead: false,
      createdAt: '7/7 14:10',
    ),
    const PlantNotification(
      id: 3,
      plantId: 1,
      message: '湿度が低下しています',
      isRead: true,
      createdAt: '7/6 08:45',
    ),
  ];

  /// 実際のHTTP通信を想定してあえて遅延させている。
  /// (画面側のローディング表示が正しく機能するかを、実サーバーが
  /// できる前から確認できるようにするため)
  Future<void> _simulateNetwork() =>
      Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<Plant> fetchPlant() async {
    await _simulateNetwork();
    return _plant;
  }

  @override
  Future<Plant> updatePlant({String? name, String? species, int? deviceId}) async {
    await _simulateNetwork();
    _plant = _plant.copyWith(name: name, species: species, deviceId: deviceId);
    return _plant;
  }

  @override
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'}) async {
    await _simulateNetwork();
    switch (range) {
      case '24h':
        // 45分間隔(3時間ごとに区切りが来るように)。
        return _generateLogs(
          span: const Duration(hours: 24),
          interval: const Duration(minutes: 45),
        );
      case '30d':
        // 12時間間隔で30日分。
        return _generateLogs(
          span: const Duration(days: 30),
          interval: const Duration(hours: 12),
        );
      case '7d':
      default:
        // 6時間間隔で7日分(1日4点、日付が変わる0時ちょうどに区切りが来る)。
        return _generateLogs(
          span: const Duration(days: 7),
          interval: const Duration(hours: 6),
        );
    }
  }

  /// ダミーの環境データ推移を作る。
  ///
  /// 気温・湿度は1日の中で緩やかに上下する波形をベースに、土壌水分は
  /// 時間経過とともにゆっくり乾いていく値に、少しだけ疑似的な揺らぎ
  /// (ノイズ)を加えて、実データっぽい推移に見せている。
  List<EnvironmentLog> _generateLogs({
    required Duration span,
    required Duration interval,
  }) {
    // range境界(24hなら3時間ごと、7d/30dなら0時ちょうど)がきれいに
    // 表示できるよう、開始時刻をinterval単位で切り捨ててそろえる。
    final now = DateTime.now();
    final intervalMs = interval.inMilliseconds;
    final rawStartMs = now.subtract(span).millisecondsSinceEpoch;
    final alignedStartMs = rawStartMs - (rawStartMs % intervalMs);
    final start = DateTime.fromMillisecondsSinceEpoch(alignedStartMs);

    final pointCount = span.inMilliseconds ~/ intervalMs;

    return [
      for (var i = 0; i <= pointCount; i++) _logAt(start.add(interval * i), i),
    ];
  }

  EnvironmentLog _logAt(DateTime t, int index) {
    final hourOfDay = t.hour + t.minute / 60;
    final noise = sin(index * 1.7) * 0.6; // 疑似的な揺らぎ

    final temperature = 26 + 3 * sin((hourOfDay - 9) / 24 * 2 * pi) + noise;
    final humidity = 60 + 8 * sin((hourOfDay - 15) / 24 * 2 * pi) + noise * 2;
    final soilMoisture = (55 - index * 0.4 + noise * 3).clamp(10.0, 90.0);
    final isDaylight = hourOfDay >= 6 && hourOfDay <= 18;
    final illuminance = isDaylight
        ? (250 + 200 * sin((hourOfDay - 6) / 12 * pi)).clamp(0.0, 500.0)
        : 0.0;

    return EnvironmentLog(
      timestamp: t,
      label: '${t.month}/${t.day} ${_twoDigits(t.hour)}:${_twoDigits(t.minute)}',
      temperature: double.parse(temperature.toStringAsFixed(1)),
      humidity: double.parse(humidity.toStringAsFixed(1)),
      soilMoisture: double.parse(soilMoisture.toStringAsFixed(1)),
      illuminance: double.parse(illuminance.toStringAsFixed(0)),
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Future<List<PlantNotification>> fetchNotifications() async {
    await _simulateNetwork();
    return List.unmodifiable(_notifications);
  }

  @override
  Future<PlantNotification> markNotificationRead(int id) async {
    await _simulateNetwork();
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) {
      throw StateError('notification not found: $id');
    }
    final updated = _notifications[index].copyWith(isRead: true);
    _notifications[index] = updated;
    return updated;
  }

  // ---- 設計書5-3 デバイスAPI(ダミー実装) ----

  @override
  Future<List<Device>> fetchDevices() async {
    await _simulateNetwork();
    return List.unmodifiable(_devices);
  }

  @override
  Future<Device> fetchDevice(int id) async {
    await _simulateNetwork();
    return _devices.firstWhere(
      (d) => d.id == id,
      orElse: () => throw StateError('device not found: $id'),
    );
  }

  @override
  Future<Device> pairDevice({
    required String deviceName,
    required String macAddress,
  }) async {
    await _simulateNetwork();
    // HttpPlantRepositoryと挙動を合わせ、同じMACアドレスなら既存デバイスを
    // 再利用する(実サーバーの409 DEVICE_ALREADY_PAIRED時のフォールバックと同じ考え方)。
    final normalized = macAddress.toUpperCase();
    for (final device in _devices) {
      if (device.macAddress.toUpperCase() == normalized) {
        return device;
      }
    }
    final device = Device(
      id: _nextDeviceId++,
      deviceName: deviceName,
      macAddress: macAddress,
      status: 'connected',
      batteryLevel: 100,
      firmwareVersion: '1.0.0',
      pairedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _devices.add(device);
    return device;
  }

  @override
  Future<void> unpairDevice(int id) async {
    await _simulateNetwork();
    _devices.removeWhere((d) => d.id == id);
    // 実サーバーのON DELETE SET NULL相当の挙動を再現する。
    if (_plant.deviceId == id) {
      _plant = _plant.copyWith(clearDeviceId: true);
    }
  }
}
