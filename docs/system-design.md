# 設計書

## 1. システム構成

```
センサー(温湿度・土壌水分・照度)
  │
  ▼
ESP32(センサーデバイス)
  │ HTTP(JSON)
  ▼
Node.js(APIサーバー)
  │
  ├── SQLite
  │
  ▼
Flutter(アプリ)
```

## 2. ディレクトリ構成

```
project
│
├── app
│   ├── screens
│   │   ├── home
│   │   ├── plant_info
│   │   ├── history
│   │   ├── notification
│   │   └── settings
│   ├── widgets
│   ├── models
│   ├── services
│   └── main.dart
│
├── server
│   ├── routes
│   ├── database
│   ├── controllers
│   └── app.js
│
├── esp32
│   └── main.ino
│
└── docs
```

## 3. 画面設計

本バージョン(v1)は1台のデバイス・1株の植物のみを管理する単独構成とし、アプリは以下5画面で構成する(複数植物への対応は将来のバージョンで検討する)。

```
ホーム(植物の状態・センサー値表示)
 ├─▶ 植物情報(植物名・植物種の確認・編集)
 ├─▶ 履歴(グラフ表示)
 ├─▶ 通知/アラート(通知一覧 → 詳細確認)
 └─▶ 設定/デバイス登録(デバイス接続・各種設定)
```

ボトムナビゲーション:ホーム / 植物 / 履歴 / 通知 / 設定

### 3-1. ホーム画面

- 登録した植物の状態(アイコン+メッセージ)・最終更新時刻を大きく表示
- 状態アイコンは3段階(元気 / 少し乾いている / 乾燥している)で表示する
- 温度・湿度・土壌水分・照度をカード形式で表示

### 3-2. 植物情報画面

- 植物名・植物種を確認・編集する
- 紐づくデバイス情報(デバイス名など)を表示

### 3-3. 履歴画面

- 土壌水分・温度・湿度の推移をグラフ表示
- 期間(直近など)でのデータ確認

### 3-4. 通知/アラート画面

- 状態悪化時の通知一覧(例:「土壌水分が少なくなっています」)
- 通知タップでホーム画面へ遷移し、対応後は状態が更新される

### 3-5. 設定/デバイス登録画面

- デバイス接続(Bluetooth/Wi-Fiでのペアリング、初回のみ)
- 通知設定(通知頻度・通知時間帯・通知音)
- デバイス設定(デバイス名・バッテリー残量・ファームウェア確認)
- ヘルプ・サポート

## 4. ユーザーフロー

> 本バージョンは認証機能を実装しない単一ユーザー構成のため、アカウント作成/ログインのステップは設けない([要件定義書 9章](requirements.md#9-制約事項)を参照)。

```
①アプリ起動 → ②デバイス接続 → ③植物の登録 → ④ホーム画面(通常時)
                                                        │
                                    ⑤通知が届く ◀───────┘(状態悪化時)
                                        │
                                    ⑥ホームで詳細を確認
                                        │
                                    ⑦状態が更新される
```

- 初回起動時はオンボーディングを表示し、そのままデバイス接続 → 植物登録へ進む
- 通常時:通知が来ていない = 安心という状態を基本とし、毎日アプリを開かなくてもよい設計とする
- その他の操作(植物情報・履歴/記録・通知設定・デバイス設定・ヘルプ)はホームからいつでもアクセス可能とする

## 5. API設計

認証機能を実装しないため、全APIは認証不要(単一ユーザー・単一端末前提)とする。ベースURLは `http://<server-ip>:port/api` とする。

### 5-1. エンドポイント一覧

| Method | URL | 内容 | 対応画面 |
|---|---|---|---|
| GET | /plants | 植物一覧取得 | ホーム |
| POST | /plants | 植物登録 | 設定/植物登録 |
| GET | /plants/:id | 植物詳細取得 | 植物詳細 |
| PATCH | /plants/:id | 植物情報編集 | 植物詳細/設定 |
| DELETE | /plants/:id | 植物削除 | 設定 |
| GET | /devices | 検出済み/登録済みデバイス一覧取得 | 設定/植物登録 |
| POST | /devices/pair | デバイスのペアリング登録 | 設定/植物登録 |
| GET | /devices/:id | デバイス情報取得(バッテリー残量等) | 設定 |
| DELETE | /devices/:id | デバイスのペアリング解除 | 設定 |
| POST | /sensor | ESP32からのセンサーデータ送信 | (デバイス→サーバー) |
| GET | /history/:plantId | 履歴取得(クエリで期間指定) | 履歴 |
| GET | /notifications | 通知一覧取得 | 通知/アラート |
| PATCH | /notifications/:id | 通知を既読にする | 通知/アラート |
| GET | /settings/notification | 通知設定取得 | 設定 |
| PUT | /settings/notification | 通知設定の更新 | 設定 |

### 5-2. 植物 API

**GET /plants レスポンス例**

```json
[
  {
    "id": 1,
    "name": "モンステラ",
    "species": "観葉植物",
    "status": "healthy",
    "temperature": 24.5,
    "humidity": 60,
    "soil": 42,
    "illuminance": 320,
    "updated_at": "2026-07-05T10:35:00"
  }
]
```

**POST /plants リクエスト例**

```json
{
  "name": "モンステラ",
  "species": "観葉植物",
  "device_id": 1,
  "image": "monstera.png"
}
```

- レスポンス:作成された植物オブジェクト(201 Created)

**PATCH /plants/:id リクエスト例**

```json
{ "name": "モンステラ(リビング)" }
```

デバイスペアリング後に紐付けを行う場合は`device_id`も指定できる(存在しないdevice_idを指定した場合は404 DEVICE_NOT_FOUNDを返す)。

```json
{ "device_id": 1 }
```

### 5-3. デバイス API

> **実装メモ(2026年8月)**: 現バージョンはBluetooth/Wi-Fiでの実機スキャン自体は未実装で、データモデル・API(本節)とdevice_id起点のセンサー受信(5-4)を先に実装した段階。アプリ側の`設定/デバイス接続`画面では、デバイス名・MACアドレスを手入力してペアリングする(実機スキャンへの置き換えは別途検討)。

**POST /devices/pair リクエスト例**

アプリがBluetooth/Wi-Fi経由でデバイスを検出した後、サーバーにペアリング情報を登録する。`mac_address`は`AA:BB:CC:DD:EE:FF`形式(コロン区切り16進数)で指定する。

```json
{
  "device_name": "Plant Monitor 01",
  "mac_address": "AA:BB:CC:DD:EE:FF"
}
```

- レスポンス:デバイスオブジェクト。この時点では植物とは紐付いていないため、続けてPATCH /plants/:idで`device_id`を設定する(5-2参照)。
- 同じ`mac_address`のデバイスが既に存在する場合は、新規作成ではなく実機の再接続(電源off/on、Wi-Fi再接続等)とみなし、既存の行を再アクティブ化して200 OKを返す(`id`は変わらない)。新規作成時は201 Createdを返す。
  - 2026年8月上旬までは409 DEVICE_ALREADY_PAIREDでエラーにしていたが、「同じ機体の再接続」は実運用上ごく普通に起こることであり、そのたびにエラーにするのは実態に合っていなかったため変更した(下記DELETE /devices/:idの変更とセット)。

**GET /devices/:id レスポンス例**

```json
{
  "id": 1,
  "device_name": "Plant Monitor 01",
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "battery_level": 85,
  "firmware_version": "1.0.2",
  "status": "connected",
  "paired_at": "2026-08-07T01:00:00Z"
}
```

存在しないIDを指定した場合は404 DEVICE_NOT_FOUNDを返す。

**DELETE /devices/:id**

ペアリング解除。**デバイス行自体は削除しない**(2026年8月上旬までは行ごと削除していたが、それだと同じ実機で再ペアリングした際に新しい連番`id`が振られてしまい、ESP32側の`DEVICE_ID`定数をそのたびに書き換える必要があった。詳細は[デバイス検証ログ01 2026-08-07](device-test-log01.md)を参照)。実際に行うのは以下の2つのみ:

1. 紐付いていた植物の`device_id`を`NULL`に戻す
2. デバイスの`status`を`disconnected`にする

同じ`mac_address`で再度`POST /devices/pair`すれば、同じ`id`のまま`status: connected`に戻る(上記参照)。

### 5-4. センサー API

**POST /sensor リクエスト例**

ESP32はデバイスIDを含めてデータを送信する(植物IDではなくデバイスIDを起点にする)。デバイスと植物は1:1で紐付くため、サーバー側で`plants.device_id`を参照してどの植物のログかを判定する(6章のテーブル定義を参照。デバイスペアリング機能の実装により、2026年8月から本設計で稼働している)。

```json
{
  "device_id": 1,
  "temperature": 24.5,
  "humidity": 61,
  "soil": 40,
  "illuminance": 300
}
```

- サーバー側は受信時に`sensor_logs`へ保存すると同時に、閾値と比較して`plants.status`を更新する(5-7参照)
- バリデーション:`device_id`は正の整数、`soil`は0〜100の数値(必須)、`temperature`は-20〜60、`humidity`は0〜100、`illuminance`は0以上の数値(任意項目は指定時のみ検証)。範囲外・型不正の場合は400 VALIDATION_ERRORを返す。
- `device_id`に紐づく植物が存在しない場合(デバイス未登録、またはデバイスがどの植物にも紐付けられていない場合)は404 PLANT_NOT_FOUNDを返す。

### 5-5. 履歴 API

**GET /history/:plantId?range=7d**

| パラメータ | 内容 |
|---|---|
| range | `24h` / `7d` / `30d`(デフォルト:`7d`) |
| from / to | rangeの代わりに期間を直接指定する場合(ISO8601) |

```json
{
  "plant_id": 1,
  "range": "7d",
  "logs": [
    { "temperature": 24.5, "humidity": 60, "soil": 42, "illuminance": 320, "created_at": "2026-07-05T10:35:00" }
  ]
}
```

### 5-6. 通知 API

**PATCH /notifications/:id リクエスト例**

```json
{ "is_read": true }
```

### 5-7. 状態(status)判定ロジック

植物の状態はサーバー側で、直近のセンサー値と閾値を比較して算出し`plants.status`に保存する(アプリ側では計算しない)。

| status | 条件(例) |
|---|---|
| healthy(元気です) | soil >= 40 |
| thirsty(少し乾いています) | 20 <= soil < 40 |
| dry(乾燥しています) | soil < 20 |

閾値は植物種ごとに変える可能性があるため、将来的には`plants`または植物種マスタに閾値カラムを持たせる拡張を想定する(現バージョンは固定閾値)。

> 上記は現行実装(土壌水分のみ)の概要。湿度・照度を含めた状態判定・通知の詳細設計は[status-notification-design.md](status-notification-design.md)を参照。

### 5-8. エラーレスポンス形式

全APIのエラーレスポンスは以下の形式に統一する。

```json
{
  "error": {
    "code": "PLANT_NOT_FOUND",
    "message": "指定された植物が見つかりません"
  }
}
```

| HTTPステータス | 内容 |
|---|---|
| 400 | リクエスト不正(バリデーションエラー) |
| 404 | 対象リソースが存在しない(例: `PLANT_NOT_FOUND` / `DEVICE_NOT_FOUND`) |
| 500 | サーバー内部エラー |

## 6. データベース設計(ER図)

認証機能を実装しないため`users`テーブルは持たず、`devices`・`plants`を起点としたシンプルな構成とする。
なお本バージョン(v1)では`devices`・`plants`ともに1レコードのみを運用する(単独構成のため)。

```mermaid
erDiagram
    DEVICES ||--o| PLANTS : "1台のデバイスが1つの植物に対応"
    PLANTS ||--o{ SENSOR_LOGS : "記録する"
    PLANTS ||--o{ NOTIFICATIONS : "発生させる"

    DEVICES {
        integer id PK
        text device_name
        text mac_address
        text firmware_version
        integer battery_level
        text status
        text paired_at
    }

    PLANTS {
        integer id PK
        integer device_id FK
        text name
        text species
        text image
        text status
        text created_at
    }

    SENSOR_LOGS {
        integer id PK
        integer plant_id FK
        real temperature
        real humidity
        real soil
        real illuminance
        text created_at
    }

    NOTIFICATIONS {
        integer id PK
        integer plant_id FK
        text message
        integer is_read
        text created_at
    }

    NOTIFICATION_SETTINGS {
        integer id PK
        text frequency
        text start_time
        text end_time
        integer sound_enabled
    }
```

> `NOTIFICATION_SETTINGS`はアプリ全体で1レコードのみ保持する設定テーブルのため、他テーブルとのリレーションは持たない(単一ユーザー構成のため)。

### devices

| 列 | 型 | 説明 |
|---|---|---|
| id | INTEGER (PK) | |
| device_name | TEXT | 例:「Plant Monitor 01」 |
| mac_address | TEXT | デバイス識別用 |
| firmware_version | TEXT | |
| battery_level | INTEGER | 0〜100 |
| status | TEXT | connected / disconnected |
| paired_at | TEXT | ペアリング日時 |

### plants

| 列 | 型 | 説明 |
|---|---|---|
| id | INTEGER (PK) | |
| device_id | INTEGER (FK → devices.id) | 紐付くデバイス(任意:未接続でも登録可) |
| name | TEXT | |
| species | TEXT | |
| image | TEXT | |
| status | TEXT | healthy / thirsty / dry(5-7のロジックで更新) |
| created_at | TEXT | |

### sensor_logs

| 列 | 型 | 説明 |
|---|---|---|
| id | INTEGER (PK) | |
| plant_id | INTEGER (FK → plants.id) | |
| temperature | REAL | |
| humidity | REAL | |
| soil | REAL | |
| illuminance | REAL | |
| created_at | TEXT | |

### notifications

| 列 | 型 | 説明 |
|---|---|---|
| id | INTEGER (PK) | |
| plant_id | INTEGER (FK → plants.id) | |
| message | TEXT | |
| is_read | INTEGER | 0 / 1 |
| created_at | TEXT | |

### notification_settings

| 列 | 型 | 説明 |
|---|---|---|
| id | INTEGER (PK) | 常に1レコードのみ運用 |
| frequency | TEXT | 例:「必要な時だけ」 |
| start_time | TEXT | 通知許可時間帯(開始) |
| end_time | TEXT | 通知許可時間帯(終了) |
| sound_enabled | INTEGER | 0 / 1 |

## 7. デザインシステム

「植物見守り」のデザインシステムは、自然を感じるやさしい色合いと十分な余白で「安心感」と「見やすさ」を大切にする。

### 7-1. カラー

| 用途 | 名称 | カラーコード |
|---|---|---|
| Primary | Deep Green | #5B7C5A |
| Secondary | Sage | #9CB89C |
| Accent | Beige | #D9C9A3 |
| Background | Ivory | #F8F5F0 |
| Surface | White | #FFFFFF |
| Text | Text Primary | #333333 |
| Status(正常) | Success | #5B7C5A |
| Status(注意) | Warning | #E7A74E |
| Status(要ケア) | Error | #D86A6A |
| Status(情報) | Info | #6CA3BF |

### 7-2. タイポグラフィ

- フォント:Noto Sans JP(Bold 700 / Medium 500 / Regular 400)
- スケール:H1 24px Bold / H2 20px Bold / Body 16px Regular / Caption 14px Regular / Overline 12px Medium

### 7-3. その他

- アイコン:Material Symbols Rounded
- スペーシング:8pxグリッド
- 角丸(Radius):4px / 8px / 16px / 24px / Full
- カード影(Shadow):X0 Y4 Blur16 Opacity15%
- ボトムナビゲーション:ホーム / 植物 / 履歴 / 通知 / 設定 の5項目で統一
- 主なコンポーネント:ボタン(メイン/アウトライン/テキスト)、Chips/Tags(状態表示)、Switch、入力フィールド、状態カード・プラントカード・通知カード・環境カード

## 8. デバイス設計

### 8-1. 部品構成

| # | 部品 | 説明 |
|---|---|---|
| 1 | ATOM Matrix | Wi-Fi/Bluetooth対応マイコンモジュール。センサーデータを収集しアプリへ送信。動作状態を色で表示(緑:正常/橙:注意/赤:エラー) |
| 2 | ATOM PortABC拡張ベース | 拡張機 |
| 3 | ENV Ⅲ | 温度・湿度・気圧センサー(I2C接続、拡張ベースPort A経由) |
| 4 | 土壌水分センサー(M5Stack用 Unit Earth、U019、抵抗式)※ | アナログ出力(ADC接続、ATOM PortABC拡張ベースのPort B経由・GPIO33)。センサー周辺に砂ポケットを設けて運用 |
| 5 | 光センサーユニット(BH1750)※2 | I2C接続(ENV IIIとは別バス。拡張ベースは経由せず、本体のGPIO26(SDA)/GPIO32(SCL)に直接配線) |
| 6 | 小型モバイルバッテリー | USB-C出力 |
| 7 | その他受動部品 | 抵抗・コンデンサ等 |

※ 土壌水分センサーはU019(抵抗式)→DFRobot Gravity 防水静電容量式土壌水分センサー V2.0(SEN0308、静電容量式)→U019(砂運用)という経緯を経て、最終的にU019に決定した。当初U019で見られた異常値(0固定、4095張り付き、数十ms単位の暴れなど)は培養土との相性(電極接触ムラ)が原因と判明し、砂状の媒体を用いることで安定動作を確認した。なお実装時、ATOM PortABC拡張ベースのPort B経由ではRAW値がADC最大値付近に張り付く現象が再発したため、配線をATOM Matrix本体のGroveポート直挿し(GPIO32)に変更し、安定動作を確認した(拡張ベースPort Bは不採用としていた)。電極の防錆・防水加工が無くM5公式もPOC(検証)用途としている点は変更されないため、長期の腐食・劣化リスクは残存する制約として許容した上での採用である。詳細は[デバイス検証ログ](device-test-log.md)を参照。

※2 光センサーは当初候補としていたU021(拡張ベース経由でのI2C/ADCピン競合・ピン不足の懸念から一時見送り)から、BH1750に変更して採用した。BH1750はENV IIIとは別のI2Cバス(Wire1)に接続するためGPIO32(SCL)を使用する必要があり、上記の土壌水分センサー(GPIO32直挿し)と競合する。そのため**土壌水分センサーの配線を再びPort B経由(GPIO33)に戻している**(下記8-2の注記を参照)。またGPIO33はESP32のADC2系のため、Wi-Fi使用中はADC1系(GPIO32)よりADC精度が不安定になりやすい点にも注意が必要。

### 8-2. 接続構成(ブロック図)

```
ATOM Matrix ──┬─▶ ATOM PortABC拡張ベース ──▶ PortA:ENV Ⅲ(I2C接続、Wireバス・SDA=GPIO25/SCL=GPIO21)
              │                          └─▶ PortB:土壌水分センサー U019(GPIO33、ADC接続、砂ポケット運用)
              ├─▶ 本体GPIO26/32直挿し(拡張ベース非経由):光センサー BH1750(I2C接続、Wire1バス・SDA=GPIO26/SCL=GPIO32)
              │
モバイルバッテリー ─▶ USB-C ─▶ ESP32
```

> **配線の変遷(2026年8月)**:土壌水分センサーは当初ATOM PortABC拡張ベースのPort B経由(GPIO33)で接続していたが、RAW値がADC最大値付近に張り付く現象が発生したため、ATOM Matrix本体のGroveポート直挿し(GPIO32)に変更した(詳細は[デバイス検証ログ 2026-08-04](device-test-log.md)を参照)。その後、光センサー(BH1750)を追加する際にGPIO32をBH1750のI2Cバス(Wire1のSCL)として使う必要が生じたため、**土壌水分センサーの配線を再びPort B経由(GPIO33)に戻している**(`esp32/plant_sensor_integrated/plant_sensor_integrated.ino`のコメント参照)。Port B経由は過去に異常値が出た配線であるため、再配線後は実機でのキャリブレーション(CALIBRATION_MODE)による再検証が必須。まだ`docs/device-test-log*.md`への正式なログ追記は済んでいない。

### 8-3. デバイス仕様

| 項目 | 内容 |
|---|---|
| 通信方式 | Wi-Fi 2.4GHz |
| 電源 | モバイルバッテリー |
| センサー | 温度・湿度・気圧(ENV Ⅲ、拡張ベースPort A経由)、土壌水分(U019、拡張ベースPort B経由・GPIO33・砂ポケット運用)、照度(BH1750、本体GPIO26/32直挿し・拡張ベース非経由) |
| 動作温度 | 0〜50℃ |
| サイズ | 約35mm × 18mm × 98mm(突起部含まず) |
| 重量 | 約30g |
| 対応アプリ | iOS / Android(専用アプリ) |
| カラー | ミルクホワイト / セージグリーン / グレージュ |

### 8-4. 通信仕様

```
ESP32
  ↓
POST /sensor
送信
{
  "device_id": 1,
  "temperature": 24.5,
  "humidity": 61,
  "soil": 40,
  "illuminance": 300
}
  ↓
Node.js
  ↓
SQLite保存
  ↓
Flutter
  ↓
GET /plants
```

## 9. データフロー

```
植物
 │
 ▼
センサー
 │
 ▼
ESP32
 │
 ▼
Node.js
 │
 ▼
SQLite
 │
 ▼
Flutter
 │
 ▼
利用者
```
