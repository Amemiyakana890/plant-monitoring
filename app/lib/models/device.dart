/// 設定/デバイス接続画面(設計書5-3)で扱うデバイス情報。
///
/// GET /devices・GET /devices/:id・POST /devices/pair のレスポンスに対応する。
class Device {
  final int id;
  final String deviceName;
  final String macAddress;
  final String? firmwareVersion;
  final int? batteryLevel;
  final String status; // 'connected' / 'disconnected'
  final String? pairedAt;

  const Device({
    required this.id,
    required this.deviceName,
    required this.macAddress,
    this.firmwareVersion,
    this.batteryLevel,
    required this.status,
    this.pairedAt,
  });

  bool get isConnected => status == 'connected';

  /// [DummyPlantRepository]がサーバー側の「再アクティブ化」ロジック
  /// (devicesController.js参照)と同じ挙動をメモリ内で再現するために使う。
  Device copyWith({String? deviceName, String? status, String? pairedAt}) {
    return Device(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      macAddress: macAddress,
      firmwareVersion: firmwareVersion,
      batteryLevel: batteryLevel,
      status: status ?? this.status,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      deviceName: json['device_name'] as String,
      macAddress: json['mac_address'] as String? ?? '',
      firmwareVersion: json['firmware_version'] as String?,
      batteryLevel: json['battery_level'] as int?,
      status: json['status'] as String? ?? 'disconnected',
      pairedAt: json['paired_at'] as String?,
    );
  }
}
