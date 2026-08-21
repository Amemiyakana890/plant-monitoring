import '../models/device.dart';
import '../models/environment_log.dart';
import '../models/notification_settings.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';
import '../models/plant_species.dart';

/// アプリが必要とするデータ取得・更新をまとめたインターフェース。
/// 設計書5章のAPI設計に対応させており、実装(現状は[DummyPlantRepository])を
/// 差し替えるだけで、画面側のコードを変更せずに
/// ダミーデータ → 実サーバー(Node.js + SQLite)への切り替えができるようにする。
abstract class PlantRepository {
  /// GET /plants/:id 相当(v1は1台のデバイス・1株のみのため単一のPlantを返す)
  Future<Plant> fetchPlant();

  /// POST /plants 相当(F-08・植物登録画面)。
  ///
  /// v1は「1台1株」の制約(要件定義書9章)のため、この呼び出しは植物が
  /// まだ1件も存在しない場合にのみ想定している(2件目以降を作らないための
  /// ガードは登録画面側・Store側で行う。本メソッド自体はガードしない)。
  ///
  /// [speciesKey]は登録フォーム側で選択必須(ラジオボタン等)にする方針のため、
  /// あえてnullableにせず必須引数にしている。通知条件(閾値)が植物種ごとに
  /// 異なる以上、「種未選択のまま植物が作られる」状態を型レベルで防ぐため。
  Future<Plant> createPlant({required String name, required String speciesKey});

  /// PATCH /plants/:id 相当。
  /// [deviceId]は「ペアリング済みデバイスをこの植物に紐付ける」場合に指定する。
  /// 紐付け解除はunpairDevice()(DELETE /devices/:id)経由で行う
  /// (サーバー側のON DELETE SET NULLで自動的にdevice_idがnullに戻るため、
  /// updatePlant側にnull化用の引数は用意していない)。
  /// [speciesKey]は植物種の選択(F-08・植物切り替え機能)。指定すると
  /// サーバー側でspeciesテキスト(表示用の植物種名)も自動的に更新される
  /// (name(ニックネーム)とは独立して扱われる)。
  Future<Plant> updatePlant({
    String? name,
    String? species,
    int? deviceId,
    String? speciesKey,
  });

  /// GET /history/:plantId?range= 相当
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'});

  /// GET /notifications 相当
  Future<List<PlantNotification>> fetchNotifications();

  /// PATCH /notifications/:id 相当
  Future<PlantNotification> markNotificationRead(int id);

  /// GET /devices 相当(設計書5-3)
  Future<List<Device>> fetchDevices();

  /// GET /devices/:id 相当(設計書5-3)
  Future<Device> fetchDevice(int id);

  /// POST /devices/pair 相当(設計書5-3)。
  /// 現状は実機のBLE/Wi-Fiスキャンには対応していないため、
  /// デバイス名・MACアドレスはアプリ側で手入力してもらう想定。
  Future<Device> pairDevice({required String deviceName, required String macAddress});

  /// DELETE /devices/:id 相当(設計書5-3「デバイスのペアリング解除」)
  Future<void> unpairDevice(int id);

  /// GET /settings/notification 相当(設計書5-1)。
  Future<NotificationSettings> fetchNotificationSettings();

  /// PUT /settings/notification 相当(設計書5-1)。
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  );

  /// POST /plants/:id/waterings 相当(docs/status-notification-design.md 4-2章)。
  /// ホーム画面の「水やりした」ボタン(widgets/plant_card.dart)から呼ぶ。
  Future<Plant> recordWatering(int plantId);

  /// GET /species 相当(F-08・植物切り替え機能)。
  /// 植物情報ページの「植物を選択する」で表示する選択肢一覧。
  Future<List<PlantSpecies>> fetchSpeciesCatalog();
}
