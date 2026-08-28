import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/models/device.dart';
import 'package:plant_monitoring_app/models/environment_log.dart';
import 'package:plant_monitoring_app/models/notification_settings.dart';
import 'package:plant_monitoring_app/models/plant.dart';
import 'package:plant_monitoring_app/models/plant_notification.dart';
import 'package:plant_monitoring_app/models/plant_species.dart';
import 'package:plant_monitoring_app/repositories/plant_repository.dart';
import 'package:plant_monitoring_app/repositories/plant_repository_exceptions.dart';
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
    this.throwNotRegisteredOnFetchPlant = false,
  });

  final Plant plant;
  final List<PlantNotification> notifications;
  final bool throwOnFetchPlant;
  final bool throwOnMarkRead;

  /// [PlantNotRegisteredException]を再現するためのフラグ。
  /// 「植物が0件」を検知するPlantStore.loadPlant()の未登録分岐のテスト用
  /// (throwOnFetchPlantとは意図的に別フラグにしている。PlantStore側で
  /// この2つを区別してハンドリングすることを検証したいため)。
  final bool throwNotRegisteredOnFetchPlant;

  @override
  Future<Plant> fetchPlant() async {
    if (throwNotRegisteredOnFetchPlant) {
      throw const PlantNotRegisteredException();
    }
    if (throwOnFetchPlant) {
      throw StateError('network error');
    }
    return plant;
  }

  @override
  Future<Plant> updatePlant({
    String? name,
    String? species,
    int? deviceId,
    String? speciesKey,
  }) async {
    if (throwOnUpdatePlant) {
      throw StateError('network error');
    }
    if (speciesKey != null) {
      final entry = speciesCatalog.firstWhere((s) => s.key == speciesKey);
      return plant.copyWith(
        speciesKey: speciesKey,
        speciesInfo: entry,
        species: entry.scientificName,
      );
    }
    return plant.copyWith(name: name, species: species, deviceId: deviceId);
  }

  bool throwOnUpdatePlant = false;

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

  // ---- 通知設定API(設計書5-1。デバイスAPIと同じく、テストでは基本未使用) ----

  NotificationSettings notificationSettings = const NotificationSettings(
    startTime: '20:00',
    endTime: '06:00',
    soundEnabled: true,
    soilAlertEnabled: true,
    temperatureAlertEnabled: true,
    humidityAlertEnabled: true,
    illuminanceAlertEnabled: true,
  );
  bool throwOnFetchNotificationSettings = false;
  bool throwOnUpdateNotificationSettings = false;

  @override
  Future<NotificationSettings> fetchNotificationSettings() async {
    if (throwOnFetchNotificationSettings) {
      throw StateError('network error');
    }
    return notificationSettings;
  }

  @override
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async {
    if (throwOnUpdateNotificationSettings) {
      throw StateError('network error');
    }
    notificationSettings = settings;
    return notificationSettings;
  }

  // ---- 水やり記録API(docs/status-notification-design.md 4-2章) ----

  bool throwOnRecordWatering = false;
  String? recordedWateringAt;

  @override
  Future<Plant> recordWatering(int plantId) async {
    if (throwOnRecordWatering) {
      throw StateError('network error');
    }
    recordedWateringAt = '2026-08-12T12:00:00Z';
    return plant.copyWith(lastWateredAt: recordedWateringAt);
  }

  // ---- 植物種カタログAPI(F-08・植物切り替え機能) ----

  List<PlantSpecies> speciesCatalog = const [
    PlantSpecies(key: 'monstera', name: 'モンステラ', scientificName: 'サトイモ科モンステラ属'),
  ];
  bool throwOnFetchSpeciesCatalog = false;

  @override
  Future<List<PlantSpecies>> fetchSpeciesCatalog() async {
    if (throwOnFetchSpeciesCatalog) {
      throw StateError('network error');
    }
    return speciesCatalog;
  }

  // ---- Push通知(FCM)用デバイストークンAPI ----

  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    String platform = 'android',
  }) async {}

  // ---- 植物登録API(F-08・植物登録画面) ----

  bool throwOnCreatePlant = false;

  // テストから「実際にどんな引数で呼ばれたか」を検証できるよう記録しておく。
  String? createdPlantName;
  String? createdPlantSpeciesKey;

  @override
  Future<Plant> createPlant({
    required String name,
    required String speciesKey,
  }) async {
    if (throwOnCreatePlant) {
      throw StateError('network error');
    }
    createdPlantName = name;
    createdPlantSpeciesKey = speciesKey;
    final entry = speciesCatalog.firstWhere((s) => s.key == speciesKey);
    return plant.copyWith(
      name: name,
      speciesKey: speciesKey,
      speciesInfo: entry,
      species: entry.scientificName,
    );
  }
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

  group('notificationSettings', () {
    test('loadNotificationSettings: 成功時はサーバーの値が設定される', () async {
      final store = PlantStore(FakePlantRepository());
      await store.loadNotificationSettings();

      expect(store.notificationSettings?.startTime, '20:00');
      expect(store.notificationSettingsErrorMessage, isNull);
    });

    test('updateNotificationSettings: 成功時は新しい設定に置き換わる', () async {
      final store = PlantStore(FakePlantRepository());
      await store.loadNotificationSettings();

      final updated = store.notificationSettings!.copyWith(
        soilAlertEnabled: false,
      );
      final ok = await store.updateNotificationSettings(updated);

      expect(ok, true);
      expect(store.notificationSettings?.soilAlertEnabled, false);
      expect(store.notificationSettingsErrorMessage, isNull);
    });

    // plant_store.dartのコメント通り「楽観的に反映し、失敗したら元の設定に
    // 戻す」設計になっているか(ロールバック)を確認する。updatePlant()や
    // markNotificationRead()と同じ考え方。
    test('updateNotificationSettings: 失敗時は元の設定に戻す', () async {
      final repository = FakePlantRepository();
      final store = PlantStore(repository);
      await store.loadNotificationSettings();
      final original = store.notificationSettings!;

      repository.throwOnUpdateNotificationSettings = true;
      final ok = await store.updateNotificationSettings(
        original.copyWith(soilAlertEnabled: false),
      );

      expect(ok, false);
      expect(
        store.notificationSettings?.soilAlertEnabled,
        original.soilAlertEnabled,
      );
      expect(store.notificationSettingsErrorMessage, isNotNull);
    });
  });

  group('recordWatering', () {
    test('成功時はサーバーが返したlast_watered_atに置き換わる', () async {
      final store = PlantStore(FakePlantRepository());
      await store.loadPlant();

      final ok = await store.recordWatering();

      expect(ok, true);
      expect(store.plant?.lastWateredAt, '2026-08-12T12:00:00Z');
      expect(store.wateringErrorMessage, isNull);
      expect(store.isRecordingWatering, false);
    });

    // plant_store.dartのコメント通り「楽観的に反映し、失敗したら元の状態に
    // 戻す」設計になっているか(ロールバック)を確認する。
    // updateNotificationSettings()と同じ考え方。
    test('失敗時は元の状態(未記録)に戻す', () async {
      final repository = FakePlantRepository()..throwOnRecordWatering = true;
      final store = PlantStore(repository);
      await store.loadPlant();
      final originalLastWateredAt = store.plant?.lastWateredAt;

      final ok = await store.recordWatering();

      expect(ok, false);
      expect(store.plant?.lastWateredAt, originalLastWateredAt);
      expect(store.wateringErrorMessage, isNotNull);
    });

    test('植物がまだ読み込まれていない場合は何もせずfalseを返す', () async {
      final store = PlantStore(FakePlantRepository());
      // loadPlant()を呼んでいないため store.plant は null のまま。

      final ok = await store.recordWatering();

      expect(ok, false);
    });
  });
}
