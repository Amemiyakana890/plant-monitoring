import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/models/environment_log.dart';
import 'package:plant_monitoring_app/models/plant.dart';
import 'package:plant_monitoring_app/models/plant_notification.dart';

void main() {
  group('PlantStatus.fromApi', () {
    test('healthy/thirsty/dryを正しく変換する', () {
      expect(PlantStatus.fromApi('healthy'), PlantStatus.healthy);
      expect(PlantStatus.fromApi('thirsty'), PlantStatus.thirsty);
      expect(PlantStatus.fromApi('dry'), PlantStatus.dry);
    });

    // plant.dartのコメント通り「未知の値はthirsty(要注意)側に倒す」という
    // 安全設計を、実際の挙動としても固定しておく。
    test('未知の値やnullはthirsty(安全側)に倒す', () {
      expect(PlantStatus.fromApi('unknown'), PlantStatus.thirsty);
      expect(PlantStatus.fromApi(null), PlantStatus.thirsty);
      expect(PlantStatus.fromApi(''), PlantStatus.thirsty);
    });
  });

  group('Plant.fromJson', () {
    test('サーバーの正常なレスポンスを変換できる', () {
      final plant = Plant.fromJson({
        'id': 1,
        'name': 'モンステラ',
        'species': '観葉植物',
        'status': 'healthy',
        'temperature': 24.5,
        'humidity': 60,
        'soil': 42,
        'illuminance': 320,
        'updated_at': '2026-08-04T01:08:52Z',
      });

      expect(plant.id, 1);
      expect(plant.name, 'モンステラ');
      expect(plant.temperature, 24.5);
      expect(plant.status, PlantStatus.healthy);
    });

    // server/controllers/plantsController.js の toPlantResponse は、
    // センサーデータが1件も届いていない植物について温度等をnullで返す。
    // その場合のフォールバック挙動(現状は0.0)を明示しておく。
    test('センサー未受信でtemperature等がnullでも例外にならない', () {
      final plant = Plant.fromJson({
        'id': 2,
        'name': '新しい植物',
        'species': null,
        'status': 'healthy',
        'temperature': null,
        'humidity': null,
        'soil': null,
        'illuminance': null,
        'updated_at': null,
      });

      expect(plant.temperature, 0.0);
      expect(plant.humidity, 0.0);
      expect(plant.soilMoisture, 0.0);
      expect(plant.illuminance, 0.0);
      expect(plant.species, '');
      expect(plant.updatedAt, '');
    });
  });

  group('Plant.updatedAtDisplay', () {
    test('UTC(Z付き)文字列をローカル時刻表記に変換する', () {
      const plant = Plant(
        id: 1,
        name: 'x',
        species: 'x',
        temperature: 0,
        humidity: 0,
        soilMoisture: 0,
        illuminance: 0,
        status: PlantStatus.healthy,
        updatedAt: '2026-08-04T01:08:52Z',
      );

      // タイムゾーンに依存させないよう、DateTime.parseした結果をtoLocal()した
      // ものと同じ文字列になっているかどうかで検証する(実行環境のTZに追従)。
      final expected = DateTime.parse('2026-08-04T01:08:52Z').toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final expectedText =
          '${expected.year}年${expected.month}月${expected.day}日 '
          '${two(expected.hour)}:${two(expected.minute)}:${two(expected.second)}';

      expect(plant.updatedAtDisplay, expectedText);
    });

    test('パースできない文字列はそのまま返す(フォールバック)', () {
      const plant = Plant(
        id: 1,
        name: 'x',
        species: 'x',
        temperature: 0,
        humidity: 0,
        soilMoisture: 0,
        illuminance: 0,
        status: PlantStatus.healthy,
        updatedAt: '不正な日付',
      );

      expect(plant.updatedAtDisplay, '不正な日付');
    });

    test('空文字は空文字のまま返す', () {
      const plant = Plant(
        id: 1,
        name: 'x',
        species: 'x',
        temperature: 0,
        humidity: 0,
        soilMoisture: 0,
        illuminance: 0,
        status: PlantStatus.healthy,
        updatedAt: '',
      );

      expect(plant.updatedAtDisplay, '');
    });
  });

  group('PlantNotification.fromJson', () {
    test('is_readがtrue/falseのbool値を解釈できる', () {
      final n = PlantNotification.fromJson({
        'id': 1,
        'plant_id': 1,
        'message': 'test',
        'is_read': true,
        'created_at': '2026-08-04T00:00:00Z',
      });
      expect(n.isRead, true);
    });

    // SQLite上はINTEGER(0/1)で保存されるため(設計書6章)、
    // 数値で届いた場合でも解釈できることを確認する。
    test('is_readが数値(0/1)でも解釈できる', () {
      final read = PlantNotification.fromJson({
        'id': 1,
        'plant_id': 1,
        'message': 'test',
        'is_read': 1,
        'created_at': '2026-08-04T00:00:00Z',
      });
      final unread = PlantNotification.fromJson({
        'id': 2,
        'plant_id': 1,
        'message': 'test',
        'is_read': 0,
        'created_at': '2026-08-04T00:00:00Z',
      });

      expect(read.isRead, true);
      expect(unread.isRead, false);
    });
  });

  group('EnvironmentLog.fromJson', () {
    test('labelを指定すればそちらが優先される', () {
      final log = EnvironmentLog.fromJson({
        'temperature': 24.5,
        'humidity': 60,
        'soil': 40,
        'illuminance': 300,
        'created_at': '2026-08-04T10:00:00Z',
      }, label: '8/4');

      expect(log.label, '8/4');
      expect(log.temperature, 24.5);
    });

    test('labelを省略した場合はcreated_atがそのまま使われる', () {
      final log = EnvironmentLog.fromJson({
        'temperature': 24.5,
        'humidity': 60,
        'soil': 40,
        'illuminance': 300,
        'created_at': '2026-08-04T10:00:00Z',
      });

      expect(log.label, '2026-08-04T10:00:00Z');
    });
  });
}
