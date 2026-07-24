/// 履歴画面(設計書5-5 GET /history/:plantId)で使う、
/// ある時点1件分の環境データ。
class EnvironmentLog {
  final String label; // 表示用ラベル(例: '7/22')
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double illuminance;

  const EnvironmentLog({
    required this.label,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
  });

  /// GET /history/:plantId のlogs配列内の1件(設計書5-5)から変換する。
  /// レスポンスは created_at(ISO8601)を持つが、グラフ用のlabelへの整形
  /// (例: "7/22")は表示側の要件次第なので、HttpPlantRepository実装時に
  /// range(24h/7d/30d)に応じたフォーマットをここで決める想定。
  factory EnvironmentLog.fromJson(Map<String, dynamic> json, {String? label}) {
    return EnvironmentLog(
      label: label ?? (json['created_at'] as String? ?? ''),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (json['soil'] as num?)?.toDouble() ?? 0.0,
      illuminance: (json['illuminance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
