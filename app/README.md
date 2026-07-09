# 🌿 Plant Monitoring App

植物の生育環境をリアルタイムで確認できるIoT植物見守りアプリです。

ESP32（M5Atom Matrix）と各種センサーを用いて取得したデータを、
Flutterアプリで確認できることを目的としています。

---

## 📱 スクリーンショット

- Home
- Plants
- History
- Notification
- Settings

---

## ✨ 主な機能

- 🌿 植物の一覧表示
- 📊 温度・湿度・土壌水分の確認
- 🌱 植物の追加・編集・削除
- 📈 環境データの履歴表示
- 🔔 通知機能
- ⚙ 設定画面

---

## 🛠 開発環境

- Flutter
- Dart
- Material Design 3

---

## 📂 ディレクトリ構成

```text
lib/
├── data/
│   └── dummy_plants.dart
│
├── models/
│   └── plant.dart
│
├── screens/
│   ├── home/
│   ├── plant_detail/
│   ├── plants/
│   ├── history/
│   ├── notification/
│   ├── settings/
│   └── main_page.dart
│
├── theme/
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   └── app_theme.dart
│
├── widgets/
│   ├── home_plant_card.dart
│   ├── plant_card.dart
│   └── summary_card.dart
│
└── main.dart
```

---

## 🚀 現在の進捗

### ✅ 完了

- Flutterプロジェクト作成
- Bottom Navigation
- Homeダッシュボード
- Plant Detail画面
- Plants管理画面
- History画面
- Notification画面
- Settings画面
- ダミーデータによる表示

### 🔄 今後実装予定

- SQLite連携
- ESP32通信
- リアルタイムデータ取得
- 照度センサー対応
- 履歴グラフ
- Push通知

---

## 🎯 コンセプト

「植物を育てる」よりも

**植物をやさしく見守る。**

必要なときだけ通知し、
毎日ホーム画面を見るだけで植物の状態が分かるアプリを目指しています。

---

## 📄 License

This project is for educational purposes.
