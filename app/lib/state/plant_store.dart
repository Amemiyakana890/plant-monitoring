import 'package:flutter/foundation.dart';

import '../models/environment_log.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';
import '../repositories/plant_repository.dart';

/// アプリ全体で共有する状態をまとめたストア。
///
/// 画面は[PlantRepository]を直接呼ばず、必ずこのストアを経由する。
/// 通信中/エラーの状態や、複数画面(ホーム・履歴・通知)をまたいだ
/// データ共有をここで一元管理するため。
class PlantStore extends ChangeNotifier {
  PlantStore(this._repository);

  final PlantRepository _repository;

  Plant? plant;
  List<EnvironmentLog> history = [];
  List<PlantNotification> notifications = [];

  bool isLoadingPlant = false;
  bool isLoadingHistory = false;
  bool isLoadingNotifications = false;
  String? errorMessage;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  /// アプリ起動時に呼び出す想定の初期読み込み。
  Future<void> loadInitial() async {
    await Future.wait([loadPlant(), loadNotifications()]);
  }

  Future<void> loadPlant() async {
    isLoadingPlant = true;
    errorMessage = null;
    notifyListeners();
    try {
      plant = await _repository.fetchPlant();
    } catch (_) {
      errorMessage = '植物の情報を取得できませんでした';
    } finally {
      isLoadingPlant = false;
      notifyListeners();
    }
  }

  Future<void> updatePlant({String? name, String? species}) async {
    plant = await _repository.updatePlant(name: name, species: species);
    notifyListeners();
  }

  Future<void> loadHistory({String range = '7d'}) async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      history = await _repository.fetchHistory(range: range);
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    isLoadingNotifications = true;
    notifyListeners();
    try {
      notifications = await _repository.fetchNotifications();
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(int id) async {
    final updated = await _repository.markNotificationRead(id);
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = updated;
      notifyListeners();
    }
  }
}
