import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/environment_level.dart';

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

/// サーバー側(docs/status-notification-design.md)が算出した
/// [EnvironmentLevel]を、表示用のラベル・色に変換する。
/// プログレスバーの[ratio]だけは実測値から別途計算して渡す
/// (バッジは日次評価、数値・バーはリアルタイム値、という3-6章の使い分けに対応)。
EnvironmentStatus environmentStatusFromLevel(
  EnvironmentLevel level, {
  required double ratio,
}) {
  switch (level) {
    case EnvironmentLevel.healthy:
      return EnvironmentStatus(ratio: ratio, label: '適正', color: AppColors.success);
    case EnvironmentLevel.caution:
      return EnvironmentStatus(ratio: ratio, label: '注意', color: AppColors.warning);
    case EnvironmentLevel.needsCare:
      return EnvironmentStatus(ratio: ratio, label: '要ケア', color: AppColors.error);
    case EnvironmentLevel.unknown:
      // 湿度・照度は1日1回(15:00)の評価のため、セットアップ直後などまだ
      // 一度も評価されていない場合がある(docs 3-6章)。誤って「適正」と
      // 見せてしまわないよう、グレー・ニュートラルな表示にする。
      return EnvironmentStatus(
        ratio: ratio,
        label: '評価準備中',
        color: Colors.grey,
      );
  }
}

/// 温度のプログレスバー用ratioを計算する(0〜45℃の範囲で正規化)。
///
/// ラベル・色(適正/注意/要ケア)は、以前はここで暫定閾値(18〜30℃)を
/// 使ってクライアント側だけで判定していたが、サーバー側で継続時間まで
/// 考慮した判定(docs/status-notification-design.md 3-1章)が入ったため、
/// [Plant.tempStatus] + [environmentStatusFromLevel] を使うように変更した。
/// このratioだけはプログレスバーの見た目のためクライアント側に残している。
double temperatureRatio(double temperature) => _clampRatio(temperature, 0, 45);

/// 湿度のプログレスバー用ratioを計算する(0〜100%の範囲で正規化)。
///
/// ラベル・色は[Plant.humidityDailyStatus](サーバー側の24時間平均による
/// 日次評価、docs 3-2章)を使う。詳細はtemperatureRatioのコメントと同様。
double humidityRatio(double humidity) => _clampRatio(humidity, 0, 100);

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

/// 照度のプログレスバー用ratioを計算する(0〜10,000luxの範囲で正規化)。
///
/// ラベル・色は[Plant.illuminanceDailyStatus](サーバー側の昼間平均による
/// 日次評価、docs 3-4章)を使う。詳細はtemperatureRatioのコメントと同様。
double illuminanceRatio(double illuminance) => _clampRatio(illuminance, 0, 10000);
