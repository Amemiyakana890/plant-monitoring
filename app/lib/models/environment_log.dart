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
}
