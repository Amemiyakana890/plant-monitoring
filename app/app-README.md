# 🌿 Plant Monitoring App

植物の生育環境をリアルタイムで確認できるIoT植物見守りアプリです。

ATOM Matrix(ESP32-WROOM-32)と各種センサーで取得したデータを、
Node.js + SQLiteのAPIサーバー経由でFlutterアプリから確認できることを目的としています。

v1は「1台のデバイス・1株の植物のみ」を管理する単独構成です(詳細は`docs/requirements.md`9章を参照)。

---

## 📱 スクリーンショット

- Home
- History
- Notification
- Plant Info
- Settings

---

## ✨ 主な機能

- 🌿 植物の状態表示(アイコン+メッセージ)
- 📊 温度・湿度・土壌水分・照度の確認(温度・土壌水分はリアルタイム、湿度・照度は1日1回15:00の日次評価。詳細は[status-notification-design.md](../docs/status-notification-design.md)を参照)
- 🌱 植物情報の確認・編集・植物種の選択(v1は1株のみ。追加・削除は将来のバージョンで検討)
- 📝 植物の新規登録(アプリ内の登録画面から`POST /plants`まで接続済み)
- 💧 水やり記録(ホーム画面の「水やりした」ボタン。履歴一覧・グラフへの反映は保留中)
- 📈 環境データの履歴表示(24h / 7d / 30d)
- 🔔 状態悪化時の通知(自動生成・既読管理・サイレントタイム・カテゴリ別ON/OFF)
- 📲 Push通知(Firebase Cloud Messaging、Android先行対応)
- 🔐 ログイン(Firebase Authentication、メール/パスワード)・サーバーAPIの保護
- ⚙ 設定画面

---

## 🛠 開発環境

- Flutter 3.41.9
- Dart 3.11.5
- Material Design 3
- サーバー: Node.js(`server/`ディレクトリ、別途起動が必要)

---

## 🚀 セットアップ

### 1. 前提ソフトウェア

- Flutter 3.41.9
- Node.js(`server/`を動かすため)
- Android: Android Studio / Android SDK
- iOS: macOS / Xcode

使用するFlutter SDKは`pubspec.yaml`の`environment.flutter`に固定されています。

### 2. APIサーバーを先に起動する

このアプリは`server/`のAPIサーバーが起動していないと、植物の情報を取得できません。

サーバー側の`.env`(プロジェクトルート直下)には、v2から`GOOGLE_APPLICATION_CREDENTIALS`(Firebase Admin SDKのサービスアカウント鍵)と`DEVICE_API_KEY`(ESP32用の認証キー)の設定が必須です。未設定のままだと`node app.js`自体は起動できますが、アプリ側のAPIリクエストが全て401になります。設定手順はルートの[README.md「環境変数」章](../README.md#環境変数)を参照してください。

```bash
cd server
npm install
node app.js
```

`植物見守り API サーバー起動: http://localhost:3000/api` と表示されればOKです。

植物の登録はアプリ内の登録画面(F-08、`app/lib/screens/onboarding/plant_registration_page.dart`)で行います。植物が0件の状態でアプリを起動すると`AppRoot`が自動でこの画面に振り分けるため、`curl`などで事前に登録しておく必要はありません。

### 3. アプリ側の接続先を設定する

`lib/config/api_config.dart`の`baseUrl`を、サーバーを動かしている環境に合わせて書き換えます。

| 実行環境 | baseUrl |
|---|---|
| Web(Chrome/Edge)・同一PC上でサーバーも起動 | `http://localhost:3000/api` |
| 実機のスマホ(同じWi-Fiに接続) | `http://<PCのLAN IP>:3000/api` |
| Androidエミュレータ | `http://10.0.2.2:3000/api` |

Web(Chrome/Edge)で動作確認する場合は、ブラウザのCORS制限により`server/app.js`側に`cors`ミドルウェアの追加が必要です。

### 4. 依存関係の取得

```bash
cd app
flutter --version
flutter pub get
```

`flutter --version`で`Flutter 3.41.9`と`Dart 3.11.5`が表示されることを確認してください。

### 5. アプリの起動

接続済み端末または起動済みエミュレーターを確認してから実行します。

```bash
flutter devices
flutter run
```

端末を指定する場合:

```bash
flutter run -d <device-id>
```

### 6. Firebase Authの設定(v2・ログイン機能)

v2からログイン機能(Firebase Auth、メール/パスワード)を追加しています。
Firebaseの公開設定値は`.env`から読み込みます(`.env.example`をコピーして設定してください)。

1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成し、
   Authentication → ログイン方法 で「メール/パスワード」を有効化しておく
2. `.env.example`を`.env`へコピーし、Firebase Consoleの各アプリ設定から値を入力する

   ```bash
   cp .env.example .env
   ```

3. Firebase ConsoleのAuthentication → ログイン方法で「メール/パスワード」を有効化する
4. `flutter pub get`を実行(`firebase_core`・`firebase_auth`が未取得の場合)

必要な設定値が不足している場合は、アプリ起動時に不足を案内します。

### 7. 品質チェック

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Pull Requestでは同じ解析とテストをGitHub Actionsが実行します。

---

## 📂 ディレクトリ構成

```text
lib/
├── config/
│   ├── api_config.dart          # サーバーのbaseUrl設定
│   └── firebase_config.dart     # .envから読み込むFirebaseの公開設定値
│
├── data/
│   └── dummy_plants.dart
│
├── models/
│   ├── plant.dart
│   ├── device.dart
│   ├── environment_log.dart
│   ├── environment_level.dart
│   ├── notification_settings.dart
│   ├── plant_notification.dart
│   └── plant_species.dart       # 植物種カタログ(GET /species)の受け取り用
│
├── repositories/
│   ├── plant_repository.dart          # サーバー通信のインターフェース
│   ├── plant_repository_exceptions.dart
│   ├── http_plant_repository.dart     # 実サーバー(Node.js)向け実装(Authorizationヘッダー付与含む)
│   └── dummy_plant_repository.dart    # 開発用ダミー実装
│
├── services/
│   └── push_notification_service.dart # Push通知(FCM)の初期化・トークン登録・受信ハンドリング
│
├── state/
│   ├── auth_store.dart / auth_store_scope.dart           # Firebase Authのログイン状態
│   ├── plant_store.dart / plant_store_scope.dart
│   ├── main_tab_controller.dart / main_tab_controller_scope.dart
│   └── theme_controller.dart / theme_controller_scope.dart
│
├── screens/
│   ├── auth/                    # ログイン画面(LoginPage)
│   ├── auth_gate.dart           # ログイン状態でLoginPage/AppRootを振り分け
│   ├── app_root.dart            # 起動直後の振り分け(未登録なら登録画面へ)
│   ├── onboarding/              # 植物の新規登録画面(F-08)
│   ├── home/
│   ├── history/
│   ├── notification/
│   ├── plant_info/
│   ├── settings/
│   └── main_page.dart
│
├── theme/
│   ├── app_colors.dart
│   ├── app_dimensions.dart
│   ├── app_text_styles.dart
│   └── app_theme.dart
│
├── utils/
│   ├── plant_status.dart
│   └── environment_status.dart
│
├── widgets/
│   ├── app_bottom_nav_bar.dart
│   ├── care_tips_card.dart
│   ├── environment_metric_card.dart
│   ├── history_line_chart.dart
│   ├── plant_card.dart
│   ├── settings_app_bar.dart
│   ├── status_hero_card.dart
│   └── summary_card.dart
│
└── main.dart
```

---

## 🚀 現在の進捗

### ✅ 完了

- Flutterプロジェクト作成
- Android / iOSプロジェクト
- Bottom Navigation
- Homeダッシュボード
- Plant Info画面とホームからの遷移
- History画面(実データのグラフ表示)
- Notification画面(実データの一覧・既読管理)
- Settings画面
- 共通テーマ・デザイン定数
- Widgetテスト・GitHub Actions
- **Node.js + SQLiteサーバーとの実通信(`HttpPlantRepository`)**
- **`/history`・`/notifications` APIとの連携**
- **状態悪化時の通知自動生成との連携動作確認**
- ESP32(実機)からのWi-Fi送信テスト
- デバイスペアリング画面(設定画面)のAPI接続
- 照度センサー(BH1750)の実接続
- 温度・湿度・照度の状態判定・通知(季節別閾値、サイレントタイム、カテゴリ別ON/OFF、複数項目同時悪化時の1件集約まで対応。詳細は[status-notification-design.md](../docs/status-notification-design.md)を参照)
- 通知設定画面(サイレントタイム・カテゴリ別アラート)のAPI接続
- 水やり記録機能(履歴一覧・グラフへの反映は保留中)
- **ログイン機能(Firebase Authentication、メール/パスワード)**。起動時に`AuthGate`でログイン状態を判定し、未ログイン時は`LoginPage`を表示(設定手順は本ファイル6章を参照)
- **サーバーAPIの保護**。サーバー側にFirebaseのIDトークン検証ミドルウェア(`server/middleware/require_auth.js`)を追加し、`/sensor`以外の全APIに適用。`POST /sensor`はESP32向けに別方式(`DEVICE_API_KEY`によるデバイス認証、`server/middleware/require_device_auth.js`)で保護。設計は[v2-firebase-security-design.md](../docs/v2-firebase-security-design.md)を参照
- **植物の新規登録画面(F-08)**。`AppRoot`が植物未登録を検知すると自動で登録画面へ振り分け、`POST /plants`まで接続済み(`app/lib/screens/onboarding/plant_registration_page.dart`)。セットアップ時に`curl`コマンドで手動登録する必要はない
- **植物種の選択・切り替え**(F-08・植物情報ページ)。`GET /species`のカタログ(モンステラ・パキラ・サンセベリア・ポトスの4種)から選び、通知の閾値・「この植物の管理条件」カードに反映される(`app/lib/screens/plant_info/plant_info_page.dart`)。あくまで「登録済みの1株がどの植物種か」を選ぶ機能であり、複数株を同時に登録・管理する機能ではない点に注意(下記「今後実装予定」参照)
- **Push通知(Firebase Cloud Messaging、Android先行)**。ログイン成功後に`PushNotificationService`が権限リクエスト・通知チャンネル作成・FCMトークン登録(`PUT /devices/tokens`)・受信ハンドリングを行う。フォアグラウンド受信時はバナーを出さず通知一覧を即時更新するのみ、バックグラウンド/終了状態はOS標準のシステム通知に任せる設計(詳細は[push-notification-design.md](../docs/push-notification-design.md)を参照)。iOS対応はAPNs証明書等が前提のため未着手

### 🔄 今後実装予定

- iOS向けPush通知対応(APNs証明書・Apple Developer Program登録が前提)
- BLEの導入(実機のBLE/Wi-Fiスキャン。現状はデバイス名・MACアドレスの手入力でペアリング)
- 複数植物(複数株)・複数デバイス対応(例:モンステラとパキラを同時に2株登録して見守る。サーバー側のAPI/DBは複数行に対応済みだが、アプリは`GET /plants`の先頭1件のみを表示・管理する実装のままで、2株目を追加する画面もまだ無い。上記の植物種選択〈4種〉とは別の課題)
- 複数ユーザー対応(単一ユーザー前提から方針転換。ユーザーごとにBLEでデバイスをペアリング・紐付けし、他ユーザーは紐付けていないデバイス/植物を扱えないようにする想定。`LoginPage`の新規登録ボタンはこの方針に伴い意図的に開放したまま。設計・残課題は[v2-firebase-security-design.md](../docs/v2-firebase-security-design.md)を参照)
- Push専用ON/OFFトグル(現状はアプリ内通知と同じ設定に連動。[push-notification-design.md](../docs/push-notification-design.md) 7章を参照)
- ログアウト時のFCMトークン削除(`DELETE /devices/tokens`は実装済みだが、`settings_page.dart`のログアウト操作からはまだ呼んでいない)

---

## 🎯 コンセプト

「植物を育てる」よりも

**植物をやさしく見守る。**

必要なときだけ通知し、
毎日ホーム画面を見るだけで植物の状態が分かるアプリを目指しています。

---

## 📄 License

This project is for educational purposes.
