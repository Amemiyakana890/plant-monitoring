# デバイス検証ログ01

このドキュメントは、センサーデバイス(ATOM Matrix周り)のハードウェア検証・トラブルシューティングの記録です。

`concept.md` / `requirements.md` / `system-design.md`は「最終的にこう決まっている」という仕様書のため、検証中の試行錯誤(症状→切り分け→結論)はこちらに時系列で記録し、仕様書側は常に「現時点の決定事項」だけを反映するようにする。

---

## 2026-08-04: 土壌水分センサー(U019)配線変更 — ATOM PortABC拡張ベース経由からATOM Matrix本体Grove直挿しへ

### 経緯

`plant_sensor_integrated.ino`への実装後、実機(ATOM PortABC拡張ベース Port B、GPIO33)でテストしたところ、
`Soil=100%`固定という事象が発生。`CALIBRATION_MODE`でRAW値を確認したところ`4081〜4091`と、
ADC最大値(4095)付近に張り付いていた。

一方、M5Stack公式サンプル(`EARTH.ino`、ATOM Matrix本体のGroveポート直挿し、GPIO32)を
単体で書き込んで確認したところ、`AnalogRead: 3861〜3871`という、張り付きのない値が
安定して得られた。

### 分かったこと

- U019単体・GPIO32直挿しでは正常に値が取得できるため、**センサー個体の不良ではない**。
- ATOM PortABC拡張ベースのPort B経由でのみ異常値(ADC最大値付近への張り付き)が発生しており、
  7/25の検証時と同様、**拡張ベースPort B側の接続(コネクタ・過電圧の可能性)に起因する問題**と
  改めて確認された。

### 対応

- `plant_sensor_integrated.ino`の`SOIL_PIN`を、拡張ベースPort B経由(GPIO33)から
  ATOM Matrix本体のGroveポート直挿し(GPIO32)に変更した。
  GPIO32はADC1系のためWi-Fi動作中でも安定して読み取れ、ENV IIIが使うI2Cピン
  (GPIO25/21、拡張ベースPort A経由)とも競合しない。
- GPIO32直挿し構成であらためて土でキャリブレーションを実施(`CALIBRATION_MODE`使用)。

  | 対象 | RAW値(5〜6サンプル) | 平均 |
  |---|---|---|
  | 乾いた土 | 3791 / 3806 / 3739 / 3747 / 3641 | 約3745 |
  | 加水後の土 | 2096 / 2022 / 1922 / 2006 / 2037 / 2039 | 約2020 |

- **この配線・センサーの組み合わせでは「乾燥時=高いRAW値、湿潤時=低いRAW値」という、
  一般的な想定(乾燥時=低い/湿潤時=高い)とは逆の向きになる**ことが判明した
  (プルアップ抵抗の掛かり方が拡張ベースPort B経由の回路と異なるためと推測されるが、
  厳密な回路的原因までは特定していない)。
- `SOIL_RAW_DRY=3745` / `SOIL_RAW_WET=2020`として反映し、実機で動作確認。
  乾いた土で`Soil=20.35%`(→`thirsty`)、加水後の土で`Soil=92.29%`(→`healthy`)と、
  閾値(5-7参照)通りの状態判定になることを確認。Flutterアプリのホーム画面・通知一覧
  にも正しく反映されることを確認した。

### 結論

- U019は**ATOM Matrix本体のGroveポート直挿し(GPIO32)であれば安定して動作する**。
  拡張ベースPort B経由は不採用とし、直挿し構成を正式な配線方針とする。
- なお、土質(培養土/砂など)によってRAW値やキャリブレーション結果が変わる可能性があるため、
  運用する土(砂ポケット等)を変更した場合は再キャリブレーションを検討すること。
- ENV III(拡張ベースPort A、I2C)とU019(本体Grove直挿し、GPIO32)の組み合わせで
  同時動作することを確認済み。照度センサー(U021)は本バージョンでは見送り、
  当面はこの2センサー構成で進める(競合懸念・ピン不足の可能性のため)。

### 今後の対応

- 運用する土質を変更した場合は`SOIL_RAW_DRY`/`WET`を再実測・更新する。
- `system-design.md` 8章(部品構成・接続構成・デバイス仕様)の配線記載を
  「拡張ベースPort B」から「本体Grove直挿し(GPIO32)」に更新(本コミットで対応)。
- 拡張ベースPort B自体の故障原因(コネクタ起因か、5V系センサーとの相性起因か)は
  未特定。優先度は下げるが、余裕があれば別センサーでの追試も検討する。
- 照度センサー(U021)は、ATOM MatrixのI2C/ADC使用状況を踏まえて追加可否を別途検討する。

### 関連ファイル

- `esp32/plant_sensor_integrated.ino` — `SOIL_PIN`をGPIO32に変更、`SOIL_RAW_DRY`/`WET`を実測値に更新
- （単体確認用）M5Stack公式サンプル`EARTH.ino`(本体Groveポート直挿し、GPIO32/26)

---

## 2026-08-07: デバイスペアリング機能(サーバー側データモデル・API)の実装

### 概要

README進捗の「デバイスペアリング機能の実装」のうち、実機でのBLE/Wi-Fiスキャンには着手せず、
まずサーバー側のデータモデル・APIとdevice_id起点の設計への切り戻しを実装した。
アプリ側のスキャンUI(`device_connection_page.dart`)は現状のモックのまま変更していない。

### 対応内容

- `server/database/db.js`: `devices`テーブルを追加、`plants`テーブルに`device_id`列を追加
  (既存の`plant_monitoring.db`に対しても`PRAGMA table_info`で存在確認のうえ
  `ALTER TABLE`でマイグレーションするようにした)
- `server/controllers/devicesController.js` / `server/routes/devices.js`:
  `GET /devices`・`POST /devices/pair`・`GET /devices/:id`・`DELETE /devices/:id`を実装
- `server/controllers/plantsController.js`: `POST /plants`・`PATCH /plants/:id`で
  `device_id`を受け取れるように変更(存在しないdevice_id指定時は404 DEVICE_NOT_FOUND)
- `server/controllers/sensorController.js`: `plant_id`を直接受け取る簡易実装から、
  設計書5-4本来の`device_id`起点の設計に戻した(`plants.device_id`で植物を引く)
- `esp32/plant_sensor_integrated.ino`: `PLANT_ID`定数を`DEVICE_ID`に変更し、
  送信JSONのキーも`device_id`に変更
- `docs/system-design.md` 5-3/5-4を実装に合わせて更新(暫定実装だった旨の注記を削除)

### 今後の対応

- アプリ側の「近くのデバイスを探す」スキャンUIを実機と接続する(BLEでの実機検出、
  または簡易的なmDNS/IP手入力での検出。方式は別途判断)
- `PlantRepository`にデバイス関連メソッド(`fetchDevices`・`pairDevice`等)を追加し、
  `device_connection_page.dart`・`device_info_page.dart`をハードコード値からAPI接続に切り替える
- ペアリング完了後、アプリ側から`PATCH /plants/:id`で`device_id`を設定するフローをUIに組み込む
  (現状はcurl等での手動設定を想定)
