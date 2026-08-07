import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/models/device.dart';
import 'package:plant_monitoring_app/models/environment_log.dart';
import 'package:plant_monitoring_app/models/plant.dart';
import 'package:plant_monitoring_app/models/plant_notification.dart';
import 'package:plant_monitoring_app/repositories/plant_repository.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';

const _plant = Plant(
  id: 1,
  name: 'モンステラ',
  species: '観葉植物',
  temperature: 24.5,
  humidity: 60,
  soilMoisture: 42,
  illuminance: 320,
  status: PlantStatus.healthy,
  updatedAt: '2026-08-04T00:00:00Z',
);

/// テストから振る舞いを制御できる[PlantRepository]の偽実装。
/// 各メソッドの成功・失敗をコンストラクタ引数で切り替えられるようにし、
/// 実際のHTTP通信やダミーの遅延(DummyPlantRepositoryの300ms)を挟まずに
/// [PlantStore]のロジックだけを検証する。
class FakePlantRepository implements PlantRepository {
  FakePlantRepository({
    this.plant = _plant,
    this.notifications = const [],
    this.throwOnFetchPlant = false,
    this.throwOnMarkRead = false,
  });

  final Plant plant;
  final List<PlantNotification> notifications;
  final bool throwOnFetchPlant;
  final bool throwOnMarkRead;

  @override
  Future<Plant> fetchPlant() async {
    if (throwOnFetchPlant) {
      throw StateError('network error');
    }
    return plant;
  }

  @override
  Future<Plant> updatePlant({String? name, String? species, int? deviceId}) async {
    return plant.copyWith(name: name, species: species, deviceId: deviceId);
  }

  @override
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'}) async {
    return [];
  }

  @override
  Future<List<PlantNotification>> fetchNotifications() async {
    return notifications;
  }

  @override
  Future<PlantNotification> markNotificationRead(int id) async {
    if (throwOnMarkRead) {
      throw StateError('network error');
    }
    final target = notifications.firstWhere((n) => n.id == id);
    return target.copyWith(isRead: true);
  }

  // ---- デバイスAPI(テストでは未使用のため、必要になったコンストラクタ引数で拡張する) ----

  final List<Device> devices = const [];
  final bool throwOnPairDevice = false;

  @override
  Future<List<Device>> fetchDevices() async => devices;

  @override
  Future<Device> fetchDevice(int id) async =>
      devices.firstWhere((d) => d.id == id);

  @override
  Future<Device> pairDevice({
    required String deviceName,
    required String macAddress,
  }) async {
    if (throwOnPairDevice) {
      throw StateError('pairing error');
    }
    return Device(
      id: 1,
      deviceName: deviceName,
      macAddress: macAddress,
      status: 'connected',
    );
  }

  @override
  Future<void> unpairDevice(int id) async {}
}

const _unreadNotification = PlantNotification(
  id: 1,
  plantId: 1,
  message: '土壌水分が少なくなっています',
  isRead: false,
  createdAt: '2026-08-04T00:00:00Z',
);

void main() {
  group('loadPlant', () {
    test('成功時はplantが設定され、errorMessageはnullのまま', () async {
      final store = PlantStore(FakePlantRepository());
      await store.loadPlant();

      expect(store.plant?.name, 'モンステラ');
      expect(store.errorMessage, isNull);
      expect(store.isLoadingPlant, false);
    });

    test('失敗時はerrorMessageが設定される', () async {
      final store = PlantStore(FakePlantRepository(throwOnFetchPlant: true));
      await store.loadPlant();

      expect(store.plant, isNull);
      expect(store.errorMessage, isNotNull);
      expect(store.isLoadingPlant, false);
    });
  });

  group('unreadNotificationCount', () {
    test('未読の件数だけをカウントする', () async {
      final store = PlantStore(
        FakePlantRepository(
          notifications: [
            _unreadNotification,
            _unreadNotification.copyWith(isRead: true),
          ],
        ),
      );
      await store.loadNotifications();

      expect(store.unreadNotificationCount, 1);
    });
  });

  group('markNotificationRead', () {
    test('成功時はサーバーの返り値で既読状態が更新される', () async {
      final store = PlantStore(
        FakePlantRepository(notifications: [_unreadNotification]),
      );
      await store.loadNotifications();

      await store.markNotificationRead(1);

      expect(store.notifications.single.isRead, true);
      expect(store.notificationsErrorMessage, isNull);
    });

    // plant_store.dartのコメント通り「楽観的に既読へ更新し、失敗したら
    // 元の状態へ戻す」設計になっているか(ロールバック)を確認する。
    test('失敗時は既読状態を元に戻し、エラーメッセージを設定する', () async {
      final store = PlantStore(
        FakePlantRepository(
          notifications: [_unreadNotification],
          throwOnMarkRead: true,
        ),
      );
      await store.loadNotifications();

      await store.markNotificationRead(1);

      expect(store.notifications.single.isRead, false); // ロールバックされている
      expect(store.notificationsErrorMessage, isNotNull);
    });

    test('既に既読の通知は何もしない(サーバーへ問い合わせない)', () async {
      final store = PlantStore(
        FakePlantRepository(
          notifications: [_unreadNotification.copyWith(isRead: true)],
          throwOnMarkRead: true, // 呼ばれたら即失敗する設定にしておき、未到達を確認
        ),
      );
      await store.loadNotifications();

      await store.markNotificationRead(1);

      expect(store.notificationsErrorMessage, isNull);
    });

    test('存在しないidを指定した場合は何もしない', () async {
      final store = PlantStore(
        FakePlantRepository(notifications: [_unreadNotification]),
      );
      await store.loadNotifications();

      await store.markNotificationRead(999);

      expect(store.notifications.single.isRead, false);
    });
  });
}
