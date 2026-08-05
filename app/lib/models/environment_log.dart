/// 履歴画面(設計書5-5 GET /history/:plantId)で使う、
/// ある時点1件分の環境データ。
class EnvironmentLog {
  /// この1件が記録された実際の日時(ローカルタイム)。
  /// 履歴画面のX軸ラベル(24hは時刻、7d/30dは日付の区切り)は
  /// これを基にhistory_page.dart側でrangeに応じて組み立てる。
  final DateTime timestamp;

  /// 簡易表示用のラベル(例: '7/22')。互換性のために残しているが、
  /// グラフの軸ラベルとしては現在使っていない([timestamp]を参照)。
  final String label;

  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double illuminance;

  const EnvironmentLog({
    required this.timestamp,
    required this.label,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
  });

  /// GET /history/:plantId のlogs配列内の1件(設計書5-5)から変換する。
  /// created_at(ISO8601)をパースして[timestamp]にし、パースできない
  /// 場合は現在時刻へフォールバックする(表示が崩れないようにするため)。
  factory EnvironmentLog.fromJson(Map<String, dynamic> json, {String? label}) {
    final rawCreatedAt = json['created_at'] as String?;
    final parsed = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt)
        : null;
    final timestamp = (parsed ?? DateTime.now()).toLocal();

    return EnvironmentLog(
      timestamp: timestamp,
      label: label ?? (rawCreatedAt ?? ''),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (json['soil'] as num?)?.toDouble() ?? 0.0,
      illuminance: (json['illuminance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
