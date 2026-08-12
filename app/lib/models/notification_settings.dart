/// GET/PUT /settings/notification (設計書5-1) のレスポンスに対応するモデル。
///
/// バッテリーアラートは含まない。ESP32側にバッテリー残量を送信する仕組み
/// 自体がまだ無く実用化はまだ先のため、今回のスコープから外している
/// (NotificationSettingsPageのバッテリーアラートのトグルは、この設定とは
/// 独立したローカルのみの表示のまま)。
class NotificationSettings {
  /// サイレントタイム(docs/status-notification-design.md 6-4章)の開始時刻。
  /// "HH:MM"形式(例: "20:00")。
  final String startTime;

  /// サイレントタイムの終了時刻。"HH:MM"形式(例: "06:00")。
  final String endTime;

  final bool soundEnabled;
  final bool soilAlertEnabled;
  final bool temperatureAlertEnabled;
  final bool humidityAlertEnabled;
  final bool illuminanceAlertEnabled;

  const NotificationSettings({
    required this.startTime,
    required this.endTime,
    required this.soundEnabled,
    required this.soilAlertEnabled,
    required this.temperatureAlertEnabled,
    required this.humidityAlertEnabled,
    required this.illuminanceAlertEnabled,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      startTime: json['start_time'] as String? ?? '20:00',
      endTime: json['end_time'] as String? ?? '06:00',
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      soilAlertEnabled: json['soil_alert_enabled'] as bool? ?? true,
      temperatureAlertEnabled:
          json['temperature_alert_enabled'] as bool? ?? true,
      humidityAlertEnabled: json['humidity_alert_enabled'] as bool? ?? true,
      illuminanceAlertEnabled:
          json['illuminance_alert_enabled'] as bool? ?? true,
    );
  }

  /// PUT /settings/notification向け。サーバー側は指定されたフィールドだけを
  /// 更新し、未指定分は現状値を維持する(server/controllers/settingsController.js
  /// 参照)。このモデルは常に全項目を保持しているため、常に全フィールドを送る。
  Map<String, dynamic> toJson() => {
    'start_time': startTime,
    'end_time': endTime,
    'sound_enabled': soundEnabled,
    'soil_alert_enabled': soilAlertEnabled,
    'temperature_alert_enabled': temperatureAlertEnabled,
    'humidity_alert_enabled': humidityAlertEnabled,
    'illuminance_alert_enabled': illuminanceAlertEnabled,
  };

  NotificationSettings copyWith({
    String? startTime,
    String? endTime,
    bool? soundEnabled,
    bool? soilAlertEnabled,
    bool? temperatureAlertEnabled,
    bool? humidityAlertEnabled,
    bool? illuminanceAlertEnabled,
  }) {
    return NotificationSettings(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soilAlertEnabled: soilAlertEnabled ?? this.soilAlertEnabled,
      temperatureAlertEnabled:
          temperatureAlertEnabled ?? this.temperatureAlertEnabled,
      humidityAlertEnabled: humidityAlertEnabled ?? this.humidityAlertEnabled,
      illuminanceAlertEnabled:
          illuminanceAlertEnabled ?? this.illuminanceAlertEnabled,
    );
  }
}
