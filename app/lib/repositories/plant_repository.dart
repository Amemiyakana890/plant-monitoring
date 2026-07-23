import '../models/environment_log.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';

/// アプリが必要とするデータ取得・更新をまとめたインターフェース。
/// 設計書5章のAPI設計に対応させており、実装(現状は[DummyPlantRepository])を
/// 差し替えるだけで、画面側のコードを変更せずに
/// ダミーデータ → 実サーバー(Node.js + SQLite)への切り替えができるようにする。
abstract class PlantRepository {
  /// GET /plants/:id 相当(v1は1台のデバイス・1株のみのため単一のPlantを返す)
  Future<Plant> fetchPlant();

  /// PATCH /plants/:id 相当
  Future<Plant> updatePlant({String? name, String? species});

  /// GET /history/:plantId?range= 相当
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'});

  /// GET /notifications 相当
  Future<List<PlantNotification>> fetchNotifications();

  /// PATCH /notifications/:id 相当
  Future<PlantNotification> markNotificationRead(int id);
}
