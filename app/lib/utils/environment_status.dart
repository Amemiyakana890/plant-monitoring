import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 環境データ1項目分の表示状態(進捗バーの割合・ラベル・色)。
class EnvironmentStatus {
  /// プログレスバー表示用に0.0〜1.0へ正規化した値。
  final double ratio;

  /// 状態タグに表示する短いラベル(例:「適正」「やや注意」)。
  final String label;

  /// プログレスバー・状態タグの色。
  final Color color;

  const EnvironmentStatus({
    required this.ratio,
    required this.label,
    required this.color,
  });
}

double _clampRatio(double value, double min, double max) {
  if (max <= min) return 0;
  return ((value - min) / (max - min)).clamp(0.0, 1.0);
}

/// 温度の状態を判定する。
///
/// TODO: 適温範囲(18〜30℃)は`plant_info_page.dart`のケアポイント文言
/// (「適温は18〜30℃、霜に弱いです」)に合わせた暫定値。
/// 設計書5-7の閾値ロジックは土壌水分のみを定義しているため、
/// 植物種ごとの適温マスタ等ができた段階で見直すこと。
EnvironmentStatus temperatureStatus(double temperature) {
  const min = 18.0;
  const max = 30.0;
  final ratio = _clampRatio(temperature, 0, 45);
  final ok = temperature >= min && temperature <= max;
  return EnvironmentStatus(
    ratio: ratio,
    label: ok ? '適正' : '注意',
    color: ok ? AppColors.success : AppColors.warning,
  );
}

/// 湿度の状態を判定する。
///
/// TODO: 適正範囲(40〜70%)は一般的な観葉植物向けの暫定値。
/// 設計書側に湿度の閾値定義がまだないため、正式な仕様が決まったら
/// system-design.md 5-7に合わせて更新すること。
EnvironmentStatus humidityStatus(double humidity) {
  const min = 40.0;
  const max = 70.0;
  final ratio = _clampRatio(humidity, 0, 100);
  final ok = humidity >= min && humidity <= max;
  return EnvironmentStatus(
    ratio: ratio,
    label: ok ? '適正' : '注意',
    color: ok ? AppColors.success : AppColors.warning,
  );
}

/// 土壌水分の状態を判定する。
///
/// 設計書5-7の`plants.status`判定ロジック(healthy/thirsty/dry)と
/// 同じ閾値(40 / 20)を使用し、表示ラベルのみ画面用に短くしている。
EnvironmentStatus soilMoistureStatus(double soil) {
  final ratio = _clampRatio(soil, 0, 100);
  if (soil >= 40) {
    return EnvironmentStatus(ratio: ratio, label: '適正', color: AppColors.success);
  }
  if (soil >= 20) {
    return EnvironmentStatus(
      ratio: ratio,
      label: 'やや注意',
      color: AppColors.warning,
    );
  }
  return EnvironmentStatus(ratio: ratio, label: '要注意', color: AppColors.error);
}

/// 照度の状態を判定する。
///
/// TODO: 適正範囲(500〜10,000lux)は室内の観葉植物向けの暫定値。
/// 光量センサー(U021)は本体未接続のため(README進捗欄参照)、
/// 実測データが揃った時点で範囲を見直すこと。
EnvironmentStatus illuminanceStatus(double illuminance) {
  const min = 500.0;
  const max = 10000.0;
  final ratio = _clampRatio(illuminance, 0, 10000);
  final ok = illuminance >= min && illuminance <= max;
  return EnvironmentStatus(
    ratio: ratio,
    label: ok ? '適正' : '注意',
    color: ok ? AppColors.success : AppColors.warning,
  );
}
