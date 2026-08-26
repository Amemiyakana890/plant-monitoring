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
- 📊 温度・湿度・土壌水分・照度の確認
- 🌱 植物情報の確認・編集(v1は1株のみ。追加・削除は将来のバージョンで検討)
- 📈 環境データの履歴表示(24h / 7d / 30d)
- 🔔 状態悪化時の通知(自動生成・既読管理)
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

```bash
cd server
npm install
node app.js
```

`植物見守り API サーバー起動: http://localhost:3000/api` と表示されればOKです。

初回のみ、動作確認用の植物を1件登録してください(v1は植物の新規登録画面がまだAPIに接続されていないため)。

```bash
curl -X POST http://localhost:3000/api/plants \
  -H "Content-Type: application/json" \
  -d '{"name":"Monstera"}'
```

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
│   └── api_config.dart          # サーバーのbaseUrl設定
│
├── data/
│   └── dummy_plants.dart
│
├── models/
│   ├── plant.dart
│   ├── environment_log.dart
│   └── plant_notification.dart
│
├── repositories/
│   ├── plant_repository.dart        # サーバー通信のインターフェース
│   ├── http_plant_repository.dart    # 実サーバー(Node.js)向け実装
│   └── dummy_plant_repository.dart   # 開発用ダミー実装
│
├── state/
│   ├── plant_store.dart
│   └── plant_store_scope.dart
│
├── screens/
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
│   └── plant_status.dart
│
├── widgets/
│   ├── history_line_chart.dart
│   ├── plant_card.dart
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

### 🔄 今後実装予定

- 植物の新規登録画面(現状はセットアップ時に`curl`コマンドで手動登録する必要がある。ルートの[README.md](../README.md)を参照)
- Push通知(現状はアプリ内の通知一覧のみ)
- BLEの導入
- サーバーAPIの保護(現状はログイン画面を経由せずサーバーへ直接アクセスできてしまう。設計は[v2-firebase-security-design.md](../docs/v2-firebase-security-design.md)を参照)

---

## 🎯 コンセプト

「植物を育てる」よりも

**植物をやさしく見守る。**

必要なときだけ通知し、
毎日ホーム画面を見るだけで植物の状態が分かるアプリを目指しています。

---

## 📄 License

This project is for educational purposes.
