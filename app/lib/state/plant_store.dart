import 'dart:async';

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

  Timer? _pollingTimer;
  bool _isPolling = false;

  Plant? plant;
  List<EnvironmentLog> history = [];
  List<PlantNotification> notifications = [];

  bool isLoadingPlant = false;
  bool isLoadingHistory = false;
  bool isLoadingNotifications = false;

  // データの種類ごとにエラーを分ける。1つの errorMessage にまとめると、
  // 例えば履歴取得の失敗が通知一覧のエラー表示を上書きしてしまうため。
  String? errorMessage;
  String? historyErrorMessage;
  String? notificationsErrorMessage;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  /// アプリ起動時に呼び出す想定の初期読み込み。
  Future<void> loadInitial() async {
    await Future.wait([loadPlant(), loadNotifications()]);
  }

  /// バックグラウンドでの自動更新(ポーリング)を開始する。
  ///
  /// ESP32はサーバーへ定期的にデータを送っているが、Flutter側は
  /// 起動時に一度取得するだけだったため、アプリを開いたままにしていても
  /// 画面をリロードしないと最新値が反映されない問題があった。
  /// これを解消するため、一定間隔でplant/notificationsだけを
  /// 静かに(ローディング表示やエラーバナーを出さずに)再取得する。
  ///
  /// loadPlant()/loadNotifications()とは別メソッドにしているのは、
  /// 「静かに見守る」というコンセプト上、通信が一時的に途切れただけで
  /// 毎回ローディングスピナーやエラーメッセージが出るのは体験として
  /// ふさわしくないため(既に表示中のデータをそのまま出し続けたい)。
  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    if (_isPolling) {
      return;
    }
    _isPolling = true;
    _pollingTimer = Timer.periodic(interval, (_) => _pollSilently());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  Future<void> _pollSilently() async {
    try {
      plant = await _repository.fetchPlant();
      // バックグラウンド更新が成功したら、以前のエラー表示も消しておく。
      errorMessage = null;
      notifyListeners();
    } catch (_) {
      // 通信が一時的に途切れただけの可能性があるため、
      // 「静かに見守る」コンセプト通り、既に表示中のデータはそのままにし
      // エラーバナーで上書きしない(サイレントに無視する)。
    }

    try {
      notifications = await _repository.fetchNotifications();
      notifyListeners();
    } catch (_) {
      // 同上の理由でサイレントに無視する。
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
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

  /// 成功時はtrue、失敗時はfalseを返す。呼び出し側(ダイアログなど)は
  /// これを見て、保存失敗をユーザーに伝えるかどうかを判断できる。
  Future<bool> updatePlant({String? name, String? species}) async {
    errorMessage = null;
    try {
      plant = await _repository.updatePlant(name: name, species: species);
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = '植物の情報を更新できませんでした';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHistory({String range = '7d'}) async {
    isLoadingHistory = true;
    historyErrorMessage = null;
    notifyListeners();
    try {
      history = await _repository.fetchHistory(range: range);
    } catch (_) {
      historyErrorMessage = '履歴を取得できませんでした';
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    isLoadingNotifications = true;
    notificationsErrorMessage = null;
    notifyListeners();
    try {
      notifications = await _repository.fetchNotifications();
    } catch (_) {
      notificationsErrorMessage = '通知を取得できませんでした';
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(int id) async {
    // 楽観的に既読へ更新し、失敗したら元の状態へ戻す。
    // (通知タップの反応を待たせたくないための設計判断)
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final previous = notifications[index];
    if (previous.isRead) return;

    notifications[index] = previous.copyWith(isRead: true);
    notifyListeners();

    try {
      final updated = await _repository.markNotificationRead(id);
      notifications[index] = updated;
    } catch (_) {
      notifications[index] = previous;
      notificationsErrorMessage = '通知の既読処理に失敗しました';
    } finally {
      notifyListeners();
    }
  }
}
