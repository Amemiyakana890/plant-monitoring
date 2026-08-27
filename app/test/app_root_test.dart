import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring_app/models/device.dart';
import 'package:plant_monitoring_app/models/environment_log.dart';
import 'package:plant_monitoring_app/models/notification_settings.dart';
import 'package:plant_monitoring_app/models/plant.dart';
import 'package:plant_monitoring_app/models/plant_notification.dart';
import 'package:plant_monitoring_app/models/plant_species.dart';
import 'package:plant_monitoring_app/repositories/plant_repository.dart';
import 'package:plant_monitoring_app/repositories/plant_repository_exceptions.dart';
import 'package:plant_monitoring_app/screens/main_page.dart';
import 'package:plant_monitoring_app/screens/onboarding/plant_registration_page.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';
import 'package:plant_monitoring_app/state/theme_controller.dart';

import 'support/test_app.dart';

/// 登録成功後に返す植物データ(createPlant()のレスポンスの元ネタ)。
const _registeredPlant = Plant(
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

const _speciesCatalog = [
  PlantSpecies(key: 'monstera', name: 'モンステラ', scientificName: 'サトイモ科モンステラ属'),
];

/// [AppRoot](TestApp経由。本物のアプリではmain.dartのPlantMonitoringAppが
/// 内部で使う)のルーティング
/// (未登録→登録画面、登録成功→MainPage)を検証するための[PlantRepository]
/// 偽実装。
///
/// test/plant_store_test.dartの`FakePlantRepository`とほぼ同じ内容だが、
/// あちらは`PlantStore`単体のロジック検証用、こちらは実際のウィジェット
/// ツリーを組み立てて検証する用途のため、あえて別ファイルに分けている
/// (中身が重複している点は、将来テスト用の共通ヘルパーに切り出す余地あり)。
class _FakePlantRepository implements PlantRepository {
  _FakePlantRepository({required this.startsRegistered});

  /// false: fetchPlant()が常に[PlantNotRegisteredException]を投げる
  ///        (= まだ植物が1件も登録されていない状態からテストを始める)。
  final bool startsRegistered;

  @override
  Future<Plant> fetchPlant() async {
    if (!startsRegistered) {
      throw const PlantNotRegisteredException();
    }
    return _registeredPlant;
  }

  @override
  Future<Plant> createPlant({
    required String name,
    required String speciesKey,
  }) async {
    final entry = _speciesCatalog.firstWhere((s) => s.key == speciesKey);
    return _registeredPlant.copyWith(
      name: name,
      speciesKey: speciesKey,
      speciesInfo: entry,
      species: entry.scientificName,
    );
  }

  @override
  Future<Plant> updatePlant({
    String? name,
    String? species,
    int? deviceId,
    String? speciesKey,
  }) async => _registeredPlant;

  @override
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'}) async => [];

  @override
  Future<List<PlantNotification>> fetchNotifications() async => [];

  @override
  Future<PlantNotification> markNotificationRead(int id) async =>
      throw UnimplementedError('このテストでは使用しない');

  @override
  Future<List<Device>> fetchDevices() async => [];

  @override
  Future<Device> fetchDevice(int id) async =>
      throw UnimplementedError('このテストでは使用しない');

  @override
  Future<Device> pairDevice({
    required String deviceName,
    required String macAddress,
  }) async {
    return Device(
      id: 1,
      deviceName: deviceName,
      macAddress: macAddress,
      status: 'connected',
    );
  }

  @override
  Future<void> unpairDevice(int id) async {}

  @override
  Future<NotificationSettings> fetchNotificationSettings() async {
    return const NotificationSettings(
      startTime: '20:00',
      endTime: '06:00',
      soundEnabled: true,
      soilAlertEnabled: true,
      temperatureAlertEnabled: true,
      humidityAlertEnabled: true,
      illuminanceAlertEnabled: true,
    );
  }

  @override
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async => settings;

  @override
  Future<Plant> recordWatering(int plantId) async => _registeredPlant;

  @override
  Future<List<PlantSpecies>> fetchSpeciesCatalog() async => _speciesCatalog;

  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    String platform = 'android',
  }) async {}
}

/// widget_test.dartと同じく、pumpAndSettle()のデフォルトタイムアウト(10分)に
/// 頼らず、数秒で明確に落ちるようにするためのラッパー。
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<PlantStore> _pumpApp(
  WidgetTester tester, {
  required bool startsRegistered,
}) async {
  final store = PlantStore(
    _FakePlantRepository(startsRegistered: startsRegistered),
  );
  addTearDown(store.dispose);
  final themeController = ThemeController();

  // main.dart本体は読み込み完了を待たずrunAppするが、テストでは結果を
  // 決定的にするため先にawaitする(widget_test.dartと同じ方針)。
  await store.loadInitial();
  await tester.pumpWidget(
    TestApp(store: store, themeController: themeController),
  );
  await _settle(tester);
  return store;
}

void main() {
  testWidgets(
    '未登録状態(GET /plantsが0件)で起動すると植物登録画面が表示される',
    (tester) async {
      await _pumpApp(tester, startsRegistered: false);

      expect(find.byType(PlantRegistrationPage), findsOneWidget);
      expect(find.byType(MainPage), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '登録済みの状態で起動するとMainPage(通常のホーム)が表示される',
    (tester) async {
      await _pumpApp(tester, startsRegistered: true);

      expect(find.byType(MainPage), findsOneWidget);
      expect(find.byType(PlantRegistrationPage), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '植物名を入力し植物種を選んで送信すると、登録に成功しMainPageへ切り替わる',
    (tester) async {
      await _pumpApp(tester, startsRegistered: false);
      expect(find.byType(PlantRegistrationPage), findsOneWidget);

      // 植物名(ニックネーム)を入力する。
      await tester.enterText(
        find.widgetWithText(TextField, '植物名(ニックネーム)'),
        'ハスター',
      );

      // 植物種のラジオボタンを選択する(カタログには「モンステラ」1件のみ)。
      await tester.tap(find.text('モンステラ'));
      await _settle(tester);

      // 送信する。
      await tester.tap(find.text('この内容で登録する'));
      await _settle(tester);

      // AppRoot(main.dart内)がstore.plant != nullを検知してMainPageへ
      // 自動的に切り替わっていることを確認する(登録画面側は
      // Navigator操作を一切行っていない点がポイント)。
      expect(find.byType(MainPage), findsOneWidget);
      expect(find.byType(PlantRegistrationPage), findsNothing);
      expect(find.text('ハスター'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '植物種を選ばずに送信すると、登録されずエラー文言が表示される',
    (tester) async {
      await _pumpApp(tester, startsRegistered: false);

      await tester.enterText(
        find.widgetWithText(TextField, '植物名(ニックネーム)'),
        'ハスター',
      );

      // 植物種は選ばずに送信する。
      await tester.tap(find.text('この内容で登録する'));
      await _settle(tester);

      // 未選択のまま登録できてしまわないこと(=通知条件の閾値が
      // 植物種ごとに異なる以上、未選択のまま作らせない、という
      // PlantRepository.createPlant()のドキュメントコメント通りの挙動)。
      expect(find.text('植物種を選択してください'), findsOneWidget);
      expect(find.byType(PlantRegistrationPage), findsOneWidget);
      expect(find.byType(MainPage), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
