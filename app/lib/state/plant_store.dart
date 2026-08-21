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
    } on PlantNotRegisteredException {
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
    needsRegistration = false;
    notifyListeners();
    try {
      plant = await _repository.fetchPlant();
    } on PlantNotRegisteredException {
      // 通信自体は成功しており、単に「まだ植物が0件」というだけなので、
      // errorMessageには入れずneedsRegistrationで表現する
      // (AppRootがこのフラグを見て登録画面に振り分ける)。
      plant = null;
      needsRegistration = true;
    } catch (_) {
      errorMessage = '植物の情報を取得できませんでした';
    } finally {
      isLoadingPlant = false;
      notifyListeners();
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
    isRegisteringPlant = true;
    registrationErrorMessage = null;
    notifyListeners();
    try {
      plant = await _repository.createPlant(name: name, speciesKey: speciesKey);
      needsRegistration = false;
      return true;
    } catch (_) {
      registrationErrorMessage = '植物を登録できませんでした';
      return false;
    } finally {
      isRegisteringPlant = false;
      notifyListeners();
    }
  }

  /// 成功時はtrue、失敗時はfalseを返す。呼び出し側(ダイアログなど)は
  /// これを見て、保存失敗をユーザーに伝えるかどうかを判断できる。
  ///
  /// [speciesKey]は植物種の選択(F-08・植物切り替え機能)専用。
  /// nameとは独立して扱われる(「植物名は自由入力、植物種はシステム的に
  /// 選択する」という運用のため。screens/plant_info/plant_info_page.dart参照)。
  Future<bool> updatePlant({String? name, String? species, String? speciesKey}) async {
    errorMessage = null;
    try {
      plant = await _repository.updatePlant(
        name: name,
        species: species,
        speciesKey: speciesKey,
      );
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

  // ---- デバイス接続(設計書5-3) ----

  Future<void> loadDevices() async {
    isLoadingDevices = true;
    devicesErrorMessage = null;
    notifyListeners();
    try {
      devices = await _repository.fetchDevices();
    } catch (_) {
      devicesErrorMessage = 'デバイス一覧を取得できませんでした';
    } finally {
      isLoadingDevices = false;
      notifyListeners();
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
    isPairing = true;
    pairErrorMessage = null;
    notifyListeners();
    try {
      final device = await _repository.pairDevice(
        deviceName: deviceName,
        macAddress: macAddress,
      );
      plant = await _repository.updatePlant(deviceId: device.id);
      devices = await _repository.fetchDevices();
      return true;
    } catch (e) {
      // 原因切り分けのため、サーバーからの実際のエラー内容(ステータス・
      // レスポンスボディ)を含めて表示する(HttpPlantRepository._ensureOk参照)。
      pairErrorMessage = 'デバイスのペアリングに失敗しました: $e';
      return false;
    } finally {
      isPairing = false;
      notifyListeners();
    }
  }

  /// ペアリング解除。サーバー側のON DELETE SET NULL(設計書6章)により、
  /// 紐付いていた植物のdevice_idも自動的にnullへ戻るため、解除後は
  /// plant/devicesの両方を再取得して画面に反映する。
  Future<bool> unpairDevice(int deviceId) async {
    pairErrorMessage = null;
    try {
      await _repository.unpairDevice(deviceId);
      await Future.wait([loadPlant(), loadDevices()]);
      return true;
    } catch (e) {
      pairErrorMessage = 'ペアリング解除に失敗しました: $e';
      notifyListeners();
      return false;
    }
  }

  // ---- 通知設定(設計書5-1)。サイレントタイム・カテゴリ別アラートのON/OFF ----

  Future<void> loadNotificationSettings() async {
    isLoadingNotificationSettings = true;
    notificationSettingsErrorMessage = null;
    notifyListeners();
    try {
      notificationSettings = await _repository.fetchNotificationSettings();
    } catch (_) {
      notificationSettingsErrorMessage = '通知設定を取得できませんでした';
    } finally {
      isLoadingNotificationSettings = false;
      notifyListeners();
    }
  }

  /// トグルの切り替え・サイレントタイムの時刻変更で共通して使う。
  /// 楽観的に画面へ反映し、失敗したら元の設定に戻す
  /// (updatePlant()と同じ考え方。UIの反応を待たせたくないため)。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> updateNotificationSettings(NotificationSettings updated) async {
    final previous = notificationSettings;
    notificationSettings = updated;
    isSavingNotificationSettings = true;
    notificationSettingsErrorMessage = null;
    notifyListeners();

    try {
      notificationSettings = await _repository.updateNotificationSettings(
        updated,
      );
      return true;
    } catch (_) {
      notificationSettings = previous;
      notificationSettingsErrorMessage = '通知設定を保存できませんでした';
      return false;
    } finally {
      isSavingNotificationSettings = false;
      notifyListeners();
    }
  }

  // ---- 水やり記録(docs/status-notification-design.md 4-2章) ----

  /// ホーム画面の「水やりした」ボタン(widgets/plant_card.dart)から呼ぶ。
  /// 楽観的に「たった今」を反映してから実際にサーバーへ記録し、
  /// 成功したらサーバーが返す正式なlast_watered_atに置き換える
  /// (updateNotificationSettings()と同じ「楽観的更新→失敗時ロールバック」の考え方)。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> recordWatering() async {
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
      plant = await _repository.recordWatering(current.id);
      return true;
    } catch (_) {
      plant = previous;
      wateringErrorMessage = '水やりの記録に失敗しました';
      return false;
    } finally {
      isRecordingWatering = false;
      notifyListeners();
    }
  }

  // ---- 植物種カタログ・切り替え(F-08・植物切り替え機能) ----

  Future<void> loadSpeciesCatalog() async {
    isLoadingSpeciesCatalog = true;
    speciesCatalogErrorMessage = null;
    notifyListeners();
    try {
      speciesCatalog = await _repository.fetchSpeciesCatalog();
    } catch (_) {
      speciesCatalogErrorMessage = '植物の選択肢を取得できませんでした';
    } finally {
      isLoadingSpeciesCatalog = false;
      notifyListeners();
    }
  }

  /// 植物情報ページの「植物を選択する」から呼ぶ。植物名(ニックネーム)には
  /// 触れず、植物種(species_key)だけを切り替える。
  /// 成功時はtrue、失敗時はfalseを返す。
  Future<bool> selectSpecies(String speciesKey) async {
    isSelectingSpecies = true;
    errorMessage = null;
    notifyListeners();
    try {
      plant = await _repository.updatePlant(speciesKey: speciesKey);
      return true;
    } catch (_) {
      errorMessage = '植物種を変更できませんでした';
      return false;
    } finally {
      isSelectingSpecies = false;
      notifyListeners();
    }
  }
}
