import '../models/device.dart';
import '../models/environment_log.dart';
import '../models/notification_settings.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';

/// アプリが必要とするデータ取得・更新をまとめたインターフェース。
/// 設計書5章のAPI設計に対応させており、実装(現状は[DummyPlantRepository])を
/// 差し替えるだけで、画面側のコードを変更せずに
/// ダミーデータ → 実サーバー(Node.js + SQLite)への切り替えができるようにする。
abstract class PlantRepository {
  /// GET /plants/:id 相当(v1は1台のデバイス・1株のみのため単一のPlantを返す)
  Future<Plant> fetchPlant();

  /// PATCH /plants/:id 相当。
  /// [deviceId]は「ペアリング済みデバイスをこの植物に紐付ける」場合に指定する。
  /// 紐付け解除はunpairDevice()(DELETE /devices/:id)経由で行う
  /// (サーバー側のON DELETE SET NULLで自動的にdevice_idがnullに戻るため、
  /// updatePlant側にnull化用の引数は用意していない)。
  Future<Plant> updatePlant({String? name, String? species, int? deviceId});

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
}
