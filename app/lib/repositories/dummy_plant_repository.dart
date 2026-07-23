import '../data/dummy_plants.dart';
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

  static const _labels = [
    '7/16',
    '7/17',
    '7/18',
    '7/19',
    '7/20',
    '7/21',
    '7/22',
  ];
  static const _temperature = [23.0, 24.0, 25.0, 24.5, 26.0, 25.0, 24.5];
  static const _humidity = [58.0, 61.0, 59.0, 60.0, 57.0, 62.0, 60.0];
  static const _soil = [55.0, 50.0, 46.0, 44.0, 40.0, 40.0, 42.0];
  static const _illuminance = [300.0, 340.0, 280.0, 320.0, 350.0, 310.0, 320.0];

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
  Future<Plant> updatePlant({String? name, String? species}) async {
    await _simulateNetwork();
    _plant = _plant.copyWith(name: name, species: species);
    return _plant;
  }

  @override
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'}) async {
    await _simulateNetwork();
    return [
      for (var i = 0; i < _labels.length; i++)
        EnvironmentLog(
          label: _labels[i],
          temperature: _temperature[i],
          humidity: _humidity[i],
          soilMoisture: _soil[i],
          illuminance: _illuminance[i],
        ),
    ];
  }

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
}
