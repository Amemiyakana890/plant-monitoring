import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/models/environment_level.dart';
import 'package:plant_monitoring_app/theme/app_colors.dart';
import 'package:plant_monitoring_app/utils/environment_status.dart';

// docs/status-notification-design.md で定義した「適正/注意/要ケア」の
// 3段階 + 未評価(unknown)を、ホーム画面向けのラベル・色に正しく
// 変換できるかを確認する。しきい値そのもの(何℃で注意か等)は
// server/test/plantStatus.test.js 側の責務であり、ここではあくまで
// 「レベル→表示」の変換のみを検証する。

void main() {
  group('environmentStatusFromLevel', () {
    test('healthyは「適正」・successカラーになる', () {
      final status = environmentStatusFromLevel(
        EnvironmentLevel.healthy,
        ratio: 0.5,
      );
      expect(status.label, '適正');
      expect(status.color, AppColors.success);
      expect(status.ratio, 0.5);
    });

    test('cautionは「注意」・warningカラーになる', () {
      final status = environmentStatusFromLevel(
        EnvironmentLevel.caution,
        ratio: 0.3,
      );
      expect(status.label, '注意');
      expect(status.color, AppColors.warning);
    });

    test('needsCareは「要ケア」・errorカラーになる', () {
      final status = environmentStatusFromLevel(
        EnvironmentLevel.needsCare,
        ratio: 0.9,
      );
      expect(status.label, '要ケア');
      expect(status.color, AppColors.error);
    });

    // 湿度・照度は1日1回(15:00)しか評価しないため、セットアップ直後などは
    // まだ評価結果が存在しない(3-6章「評価準備中」表示)。
    // 誤って「適正」に見えてしまわないよう、専用のニュートラル表示になることを確認する。
    test('unknownは「評価準備中」・適正/注意/要ケアと異なる色になる', () {
      final status = environmentStatusFromLevel(
        EnvironmentLevel.unknown,
        ratio: 0.0,
      );
      expect(status.label, '評価準備中');
      expect(status.color, isNot(AppColors.success));
      expect(status.color, isNot(AppColors.warning));
      expect(status.color, isNot(AppColors.error));
    });
  });

  group('EnvironmentLevel.fromApi', () {
    test('healthy/caution/needs_careを正しく変換する', () {
      expect(EnvironmentLevel.fromApi('healthy'), EnvironmentLevel.healthy);
      expect(EnvironmentLevel.fromApi('caution'), EnvironmentLevel.caution);
      expect(EnvironmentLevel.fromApi('needs_care'), EnvironmentLevel.needsCare);
    });

    test('null・未知の値はunknownになる(適正と誤解されないための安全側)', () {
      expect(EnvironmentLevel.fromApi(null), EnvironmentLevel.unknown);
      expect(EnvironmentLevel.fromApi('foo'), EnvironmentLevel.unknown);
      expect(EnvironmentLevel.fromApi(''), EnvironmentLevel.unknown);
    });
  });

  group('temperatureRatio / humidityRatio / illuminanceRatio', () {
    test('範囲内の値は0.0〜1.0に正規化される', () {
      expect(temperatureRatio(0), 0.0);
      expect(temperatureRatio(45), 1.0);
      expect(humidityRatio(0), 0.0);
      expect(humidityRatio(100), 1.0);
      expect(illuminanceRatio(0), 0.0);
      expect(illuminanceRatio(10000), 1.0);
    });

    test('範囲外の値は0.0〜1.0にクランプされる', () {
      expect(temperatureRatio(-10), 0.0);
      expect(temperatureRatio(100), 1.0);
      expect(illuminanceRatio(-100), 0.0);
      expect(illuminanceRatio(999999), 1.0);
    });
  });
}
