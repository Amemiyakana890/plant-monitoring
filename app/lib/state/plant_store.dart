import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../models/environment_log.dart';
import '../models/notification_settings.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';
import '../models/plant_species.dart';
import '../repositories/plant_repository.dart';
import '../repositories/plant_repository_exceptions.dart';

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
  int _sessionGeneration = 0;

  Plant? plant;
  List<EnvironmentLog> history = [];
  List<PlantNotification> notifications = [];
  List<Device> devices = [];
  NotificationSettings? notificationSettings;
  List<PlantSpecies> speciesCatalog = [];

  bool isLoadingPlant = false;
  bool isLoadingHistory = false;
  bool isLoadingNotifications = false;
  bool isLoadingDevices = false;
  bool isPairing = false;
  bool isLoadingNotificationSettings = false;
  bool isSavingNotificationSettings = false;
  bool isRecordingWatering = false;
  bool isLoadingSpeciesCatalog = false;
  bool isSelectingSpecies = false;
  bool isRegisteringPlant = false;

  /// GET /plants が0件(=まだ植物が登録されていない)ことを検知した状態。
  /// [AppRoot](screens/app_root.dart)はこれを見て登録画面へ振り分ける。
  /// 通信エラー([errorMessage])とは意図的に別のフラグにしている
  /// (両者でアプリの振る舞い(登録画面へ誘導 or 再試行を促す)が異なるため)。
  bool needsRegistration = false;

  // データの種類ごとにエラーを分ける。1つの errorMessage にまとめると、
  // 例えば履歴取得の失敗が通知一覧のエラー表示を上書きしてしまうため。
  String? errorMessage;
  String? historyErrorMessage;
  String? notificationsErrorMessage;
  String? devicesErrorMessage;
  String? pairErrorMessage;
  String? notificationSettingsErrorMessage;
  String? wateringErrorMessage;
  String? speciesCatalogErrorMessage;
  String? registrationErrorMessage;
  String? _newDeviceApiKey;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  String? takeNewDeviceApiKey() {
    final key = _newDeviceApiKey;
    _newDeviceApiKey = null;
    return key;
  }

  void clearUserData() {
    _sessionGeneration++;
    plant = null;
    history = [];
    notifications = [];
    devices = [];
    notificationSettings = null;
    speciesCatalog = [];
    needsRegistration = false;
    errorMessage = null;
    historyErrorMessage = null;
    notificationsErrorMessage = null;
    devicesErrorMessage = null;
    pairErrorMessage = null;
    notificationSettingsErrorMessage = null;
    wateringErrorMessage = null;
    speciesCatalogErrorMessage = null;
    registrationErrorMessage = null;
    _newDeviceApiKey = null;
    isLoadingPlant = false;
    isLoadingHistory = false;
    isLoadingNotifications = false;
    isLoadingDevices = false;
    isPairing = false;
    isLoadingNotificationSettings = false;
    isSavingNotificationSettings = false;
    isRecordingWatering = false;
    isLoadingSpeciesCatalog = false;
    isSelectingSpecies = false;
    isRegisteringPlant = false;
    notifyListeners();
  }

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
    final generation = _sessionGeneration;
    try {
      final fetchedPlant = await _repository.fetchPlant();
      if (generation != _sessionGeneration) return;
      plant = fetchedPlant;
      // バックグラウンド更新が成功したら、以前のエラー表示も消しておく。
      errorMessage = null;
      notifyListeners();
    } on PlantNotRegisteredException {
      if (generation != _sessionGeneration) return;
      // 起動中に植物が削除された等、ポーリング中に0件へ変わった場合。
      // これは一時的な通信不調ではなく実際の状態変化なので、他の通信エラーと
      // 異なりサイレントに無視せず、登録画面へ戻す(AppRoot参照)。
      plant = null;
      needsRegistration = true;
      notifyListeners();
    } catch (_) {
      // 通信が一時的に途切れただけの可能性があるため、
      // 「静かに見守る」コンセプト通り、既に表示中のデータはそのままにし
      // エラーバナーで上書きしない(サイレントに無視する)。
    }

    if (generation != _sessionGeneration) return;

    try {
      final fetchedNotifications = await _repository.fetchNotifications();
      if (generation != _sessionGeneration) return;
      notifications = fetchedNotifications;
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
    final generation = _sessionGeneration;
    isLoadingPlant = true;
    errorMessage = null;
    needsRegistration = false;
    notifyListeners();
    try {
      final fetchedPlant = await _repository.fetchPlant();
      if (generation != _sessionGeneration) return;
      plant = fetchedPlant;
    } on PlantNotRegisteredException {
      if (generation != _sessionGeneration) return;
      // 通信自体は成功しており、単に「まだ植物が0件」というだけなので、
      // errorMessageには入れずneedsRegistrationで表現する
      // (AppRootがこのフラグを見て登録画面に振り分ける)。
      plant = null;
      needsRegistration = true;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      errorMessage = '植物の情報を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingPlant = false;
        notifyListeners();
      }
    }
  }

  /// 植物登録画面(F-08)から呼ぶ。POST /plants 相当。
  ///
  /// [speciesKey]は登録フォーム側でラジオボタン等により選択必須にする方針の
  /// ため、ここでも必須引数にしている([PlantRepository.createPlant]参照)。
  /// 成功時はtrue、失敗時はfalse(registrationErrorMessageにメッセージを設定)。
  Future<bool> registerPlant({
    required String name,
    required String speciesKey,
  }) async {
    final generation = _sessionGeneration;
    isRegisteringPlant = true;
    registrationErrorMessage = null;
    notifyListeners();
    try {
      final createdPlant = await _repository.createPlant(
        name: name,
        speciesKey: speciesKey,
      );
      if (generation != _sessionGeneration) return false;
      plant = createdPlant;
      needsRegistration = false;
      return true;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      registrationErrorMessage = '植物を登録できませんでした';
      return false;
    } finally {
      if (generation == _sessionGeneration) {
        isRegisteringPlant = false;
        notifyListeners();
      }
    }
  }

  /// 成功時はtrue、失敗時はfalseを返す。呼び出し側(ダイアログなど)は
  /// これを見て、保存失敗をユーザーに伝えるかどうかを判断できる。
  ///
  /// [speciesKey]は植物種の選択(F-08・植物切り替え機能)専用。
  /// nameとは独立して扱われる(「植物名は自由入力、植物種はシステム的に
  /// 選択する」という運用のため。screens/plant_info/plant_info_page.dart参照)。
  Future<bool> updatePlant({
    String? name,
    String? species,
    String? speciesKey,
  }) async {
    final generation = _sessionGeneration;
    errorMessage = null;
    try {
      final updatedPlant = await _repository.updatePlant(
        name: name,
        species: species,
        speciesKey: speciesKey,
      );
      if (generation != _sessionGeneration) return false;
      plant = updatedPlant;
      notifyListeners();
      return true;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      errorMessage = '植物の情報を更新できませんでした';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHistory({String range = '7d'}) async {
    final generation = _sessionGeneration;
    isLoadingHistory = true;
    historyErrorMessage = null;
    notifyListeners();
    try {
      final fetchedHistory = await _repository.fetchHistory(range: range);
      if (generation != _sessionGeneration) return;
      history = fetchedHistory;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      historyErrorMessage = '履歴を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadNotifications() async {
    final generation = _sessionGeneration;
    isLoadingNotifications = true;
    notificationsErrorMessage = null;
    notifyListeners();
    try {
      final fetchedNotifications = await _repository.fetchNotifications();
      if (generation != _sessionGeneration) return;
      notifications = fetchedNotifications;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      notificationsErrorMessage = '通知を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingNotifications = false;
        notifyListeners();
      }
    }
  }

  Future<void> markNotificationRead(int id) async {
    final generation = _sessionGeneration;
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
      if (generation != _sessionGeneration) return;
      notifications[index] = updated;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      notifications[index] = previous;
      notificationsErrorMessage = '通知の既読処理に失敗しました';
    } finally {
      if (generation == _sessionGeneration) {
        notifyListeners();
      }
    }
  }

  // ---- デバイス接続(設計書5-3) ----

  Future<void> loadDevices() async {
    final generation = _sessionGeneration;
    isLoadingDevices = true;
    devicesErrorMessage = null;
    notifyListeners();
    try {
      final fetchedDevices = await _repository.fetchDevices();
      if (generation != _sessionGeneration) return;
      devices = fetchedDevices;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      devicesErrorMessage = 'デバイス一覧を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingDevices = false;
        notifyListeners();
      }
    }
  }

  /// デバイスをペアリングし、続けて現在の植物に紐付ける。
  ///
  /// v1は「1台のデバイス・1株のみ」という制約(要件定義書9章)のため、
  /// ペアリングと紐付けを1操作にまとめている(複数デバイス対応時は
  /// 「ペアリングだけ行い、紐付け先の植物を選ぶ」フローに分離する想定)。
  /// 成功時はtrue、失敗時はfalse(pairErrorMessageにメッセージを設定)。
  ///
  /// 失敗理由がデバイス一覧のエラー(devicesErrorMessage)と混ざらないよう、
  /// 専用のpairErrorMessageに分けている(以前は共用しており、一覧側にも
  /// ペアリング失敗の文言が出てしまう不具合があった)。
  Future<bool> pairAndLinkDevice({
    required String deviceName,
    required String macAddress,
  }) async {
    final generation = _sessionGeneration;
    isPairing = true;
    pairErrorMessage = null;
    notifyListeners();
    try {
      final device = await _repository.pairDevice(
        deviceName: deviceName,
        macAddress: macAddress,
      );
      if (generation != _sessionGeneration) return false;
      _newDeviceApiKey = device.deviceApiKey;
      final updatedPlant = await _repository.updatePlant(deviceId: device.id);
      if (generation != _sessionGeneration) return false;
      plant = updatedPlant;
      final fetchedDevices = await _repository.fetchDevices();
      if (generation != _sessionGeneration) return false;
      devices = fetchedDevices;
      return true;
    } catch (e) {
      if (generation != _sessionGeneration) return false;
      // 原因切り分けのため、サーバーからの実際のエラー内容(ステータス・
      // レスポンスボディ)を含めて表示する(HttpPlantRepository._ensureOk参照)。
      pairErrorMessage = 'デバイスのペアリングに失敗しました: $e';
      return false;
    } finally {
      if (generation == _sessionGeneration) {
        isPairing = false;
        notifyListeners();
      }
    }
  }

  /// ペアリング解除。サーバー側のON DELETE SET NULL(設計書6章)により、
  /// 紐付いていた植物のdevice_idも自動的にnullへ戻るため、解除後は
  /// plant/devicesの両方を再取得して画面に反映する。
  Future<bool> unpairDevice(int deviceId) async {
    final generation = _sessionGeneration;
    pairErrorMessage = null;
    try {
      await _repository.unpairDevice(deviceId);
      if (generation != _sessionGeneration) return false;
      await Future.wait([loadPlant(), loadDevices()]);
      return true;
    } catch (e) {
      if (generation != _sessionGeneration) return false;
      pairErrorMessage = 'ペアリング解除に失敗しました: $e';
      notifyListeners();
      return false;
    }
  }

  // ---- 通知設定(設計書5-1)。サイレントタイム・カテゴリ別アラートのON/OFF ----

  Future<void> loadNotificationSettings() async {
    final generation = _sessionGeneration;
    isLoadingNotificationSettings = true;
    notificationSettingsErrorMessage = null;
    notifyListeners();
    try {
      final fetchedSettings = await _repository.fetchNotificationSettings();
      if (generation != _sessionGeneration) return;
      notificationSettings = fetchedSettings;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      notificationSettingsErrorMessage = '通知設定を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingNotificationSettings = false;
        notifyListeners();
      }
    }
  }

  /// トグルの切り替え・サイレントタイムの時刻変更で共通して使う。
  /// 楽観的に画面へ反映し、失敗したら元の設定に戻す
  /// (updatePlant()と同じ考え方。UIの反応を待たせたくないため)。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> updateNotificationSettings(NotificationSettings updated) async {
    final generation = _sessionGeneration;
    final previous = notificationSettings;
    notificationSettings = updated;
    isSavingNotificationSettings = true;
    notificationSettingsErrorMessage = null;
    notifyListeners();

    try {
      final savedSettings = await _repository.updateNotificationSettings(
        updated,
      );
      if (generation != _sessionGeneration) return false;
      notificationSettings = savedSettings;
      return true;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      notificationSettings = previous;
      notificationSettingsErrorMessage = '通知設定を保存できませんでした';
      return false;
    } finally {
      if (generation == _sessionGeneration) {
        isSavingNotificationSettings = false;
        notifyListeners();
      }
    }
  }

  // ---- 水やり記録(docs/status-notification-design.md 4-2章) ----

  /// ホーム画面の「水やりした」ボタン(widgets/plant_card.dart)から呼ぶ。
  /// 楽観的に「たった今」を反映してから実際にサーバーへ記録し、
  /// 成功したらサーバーが返す正式なlast_watered_atに置き換える
  /// (updateNotificationSettings()と同じ「楽観的更新→失敗時ロールバック」の考え方)。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> recordWatering() async {
    final generation = _sessionGeneration;
    final current = plant;
    if (current == null) return false;

    final previous = current;
    plant = current.copyWith(
      lastWateredAt: DateTime.now().toUtc().toIso8601String(),
    );
    isRecordingWatering = true;
    wateringErrorMessage = null;
    notifyListeners();

    try {
      final updatedPlant = await _repository.recordWatering(current.id);
      if (generation != _sessionGeneration) return false;
      plant = updatedPlant;
      return true;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      plant = previous;
      wateringErrorMessage = '水やりの記録に失敗しました';
      return false;
    } finally {
      if (generation == _sessionGeneration) {
        isRecordingWatering = false;
        notifyListeners();
      }
    }
  }

  // ---- 植物種カタログ・切り替え(F-08・植物切り替え機能) ----

  Future<void> loadSpeciesCatalog() async {
    final generation = _sessionGeneration;
    isLoadingSpeciesCatalog = true;
    speciesCatalogErrorMessage = null;
    notifyListeners();
    try {
      final catalog = await _repository.fetchSpeciesCatalog();
      if (generation != _sessionGeneration) return;
      speciesCatalog = catalog;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      speciesCatalogErrorMessage = '植物の選択肢を取得できませんでした';
    } finally {
      if (generation == _sessionGeneration) {
        isLoadingSpeciesCatalog = false;
        notifyListeners();
      }
    }
  }

  /// 植物情報ページの「植物を選択する」から呼ぶ。植物名(ニックネーム)には
  /// 触れず、植物種(species_key)だけを切り替える。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> selectSpecies(String speciesKey) async {
    final generation = _sessionGeneration;
    isSelectingSpecies = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updatedPlant = await _repository.updatePlant(
        speciesKey: speciesKey,
      );
      if (generation != _sessionGeneration) return false;
      plant = updatedPlant;
      return true;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      errorMessage = '植物種を変更できませんでした';
      return false;
    } finally {
      if (generation == _sessionGeneration) {
        isSelectingSpecies = false;
        notifyListeners();
      }
    }
  }
}
