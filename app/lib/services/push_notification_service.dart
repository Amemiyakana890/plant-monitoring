import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../repositories/plant_repository.dart';
import '../state/main_tab_controller.dart';
import '../state/plant_store.dart';

/// Android向けのPush通知チャンネル(docs/push-notification-design.md 6-4章)。
///
/// チャンネルIDは`android/app/src/main/AndroidManifest.xml`の
/// `com.google.firebase.messaging.default_notification_channel_id`と
/// 一致させる必要がある。サーバー側(server/utils/pushNotifier.js)は特定の
/// チャンネルIDをFCMペイロードに指定していないため、これがPush通知の
/// 既定チャンネルとして使われる。
const AndroidNotificationChannel pushNotificationAndroidChannel =
    AndroidNotificationChannel(
      'plant_monitoring_alerts',
      '植物の状態通知',
      description: '植物の状態が悪化した際の通知(土壌水分・温度・湿度・照度)',
      importance: Importance.high,
    );

/// メイン画面のボトムナビゲーションにおける「通知」タブのインデックス。
/// `screens/main_page.dart`の`_pages`の並び順(ホーム/植物情報/履歴/通知/設定)
/// に対応させている。並び順を変えた場合はここも合わせて変更すること。
const int notificationTabIndex = 3;

/// Push通知(FCM)まわりの初期化・トークン登録・受信ハンドリングをまとめたサービス。
///
/// `main.dart`の`_onAuthChanged()`から、ログイン成功後に[initialize]を呼ぶ想定
/// (docs/push-notification-design.md 6-2章)。現時点ではAndroid先行のため、
/// iOS固有の設定(APNs等)はこのクラスでは扱っていない(docs 9-2章参照)。
class PushNotificationService {
  PushNotificationService({
    required PlantRepository repository,
    required PlantStore plantStore,
    required MainTabController tabController,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _repository = repository,
       _plantStore = plantStore,
       _tabController = tabController,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final PlantRepository _repository;
  final PlantStore _plantStore;
  final MainTabController _tabController;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;

  /// ログイン成功後に一度だけ呼ぶ。権限リクエスト・通知チャンネル作成・
  /// FCMトークン登録・受信ハンドリングの購読をまとめて行う。
  ///
  /// 2回目以降の呼び出しは何もしない([_initialized]で防止)。ログアウト→
  /// 再ログインを繰り返しても、購読(`listen`)が重複登録されないようにするため。
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Web実行時は初期化自体をスキップする。要件定義書8章の対応OSは
    // iOS/Androidのみで、Web実行(`flutter run -d chrome`)は開発確認用のため。
    // また、firebase_messagingのWeb実装はgetToken()呼び出し時に
    // Service Worker(web/firebase-messaging-sw.js)の登録を試みるが、
    // 本プロジェクトはそのファイルを用意していないため、登録に失敗して
    // 未処理のPromiseエラーになってしまう(コンソールに
    // `failed-service-worker-registration`として出るのはこれが原因)。
    // Web版のPush通知に本格対応する場合は、この早期returnを外した上で
    // 該当のservice workerファイルを追加すること。
    if (kIsWeb) return;

    await _createAndroidChannel();

    // Android 13(API 33)以降はランタイム通知権限が必要
    // (AndroidManifest.xmlのPOST_NOTIFICATIONS宣言と対になる。docs 6-2章)。
    await _messaging.requestPermission();

    await _registerCurrentToken();
    _messaging.onTokenRefresh.listen(_registerToken);

    // フォアグラウンド受信:バナー等は出さず、通知一覧を即時再取得するのみ
    // (docs 6-3章・「必要な時だけ、そっと知らせる」というコンセプトを優先する
    // 決定。PlantStoreは既に30秒間隔でポーリングしているため、ここでは
    // その反映を早めるだけの役割)。
    FirebaseMessaging.onMessage.listen((_) {
      _plantStore.loadNotifications();
    });

    // バックグラウンド中に通知をタップして復帰した場合・終了状態から通知を
    // タップして起動した場合は、通知一覧タブへ遷移させる(docs 6-3章)。
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotificationTab());
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openNotificationTab();
    }

    // 注意: バックグラウンド/終了状態からの受信そのもの
    // (FirebaseMessaging.onBackgroundMessage)は実装していない。現在の
    // サーバー実装(server/utils/pushNotifier.js)は`notification`ペイロードの
    // みを送っており、この場合OSが自動でシステム通知を表示するため追加実装は
    // 不要(docs 6-3章の表を参照)。将来dataペイロードを使った独自処理が
    // 必要になった場合は、トップレベル関数のハンドラを
    // `FirebaseMessaging.onBackgroundMessage()`で登録すること(別Isolateで
    // 実行される可能性があるため、そのハンドラ内で改めて
    // `Firebase.initializeApp()`を呼ぶ必要がある)。
  }

  Future<void> _createAndroidChannel() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(pushNotificationAndroidChannel);
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _repository.registerDeviceToken(fcmToken: token);
    } catch (error) {
      // Push通知の登録に失敗しても、アプリの他の機能(通知一覧はポーリングで
      // 引き続き更新される)には影響させない。ログインし直した際などに
      // 再試行される想定。
      debugPrint('FCMトークンの登録に失敗しました: $error');
    }
  }

  void _openNotificationTab() {
    _tabController.setIndex(notificationTabIndex);
  }
}
