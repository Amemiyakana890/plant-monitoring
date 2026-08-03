# デバイス検証ログ

このドキュメントは、センサーデバイス(ATOM Matrix周り)のハードウェア検証・トラブルシューティングの記録です。

`concept.md` / `requirements.md` / `system-design.md`は「最終的にこう決まっている」という仕様書のため、検証中の試行錯誤(症状→切り分け→結論)はこちらに時系列で記録し、仕様書側は常に「現時点の決定事項」だけを反映するようにする。

---

## 2026-07-29: ESP32のWi-Fi送信対応(secrets.h分離)

`esp32/plant_sensor_integrated.ino`にENV IIIのWi-Fi送信機能を追加。
Wi-Fi情報・サーバーIPは`.env`と同じ考え方でGit管理対象外の
`esp32/plant_sensor_integrated/secrets.h`に分離した
(テンプレートは`secrets.h.example`、`.gitignore`に`esp32/**/secrets.h`を追加済み)。

### 今後の対応

- `secrets.h`に実際のWi-Fi SSID・パスワード・サーバーIPを書き込み、実機で送信確認を行う
- 土壌水分は仮値(`PLACEHOLDER_SOIL_VALUE = 50.0`)を送信している状態のため、
  SEN0308到着後は`SOIL_SENSOR_CONNECTED`を`true`にし、`readSoilMoisture()`を実測に差し替える

---

## 2026-07-31: ESP32実機からのWi-Fi自動送信・モバイルバッテリー給電テスト

### 使用機材

- ATOM Matrix + ATOMIC PortABC拡張ベース
- M5Stack用温湿度気圧センサユニット Ver.3(ENV III、Port A・I2C接続)
- 小型モバイルバッテリー(USB-C給電)

### 経緯・結果

1. `esp32/plant_sensor_integrated.ino`にWi-Fi接続 + `POST /sensor`送信処理を実装。
   Wi-Fi情報・サーバーIPは`.env`と同じ考え方で`secrets.h`(Git管理対象外)に分離し、
   `secrets.h.example`をテンプレートとしてコミットする形にした。
2. サーバー側は同一LAN内の別デバイスからのアクセスになるため、Windows Defender
   ファイアウォールで3000番ポートの受信を許可する対応が必要だった
   (`New-NetFirewallRule`、または`node app.js`初回起動時のポップアップから許可)。
3. 上記対応後、ATOM MatrixからNode.jsサーバーへの自動送信(30秒間隔)が成功。
   シリアルモニタで`HTTP 201`とstatus判定結果を継続的に確認できた。
4. Flutterアプリ側に自動ポーリング(30秒間隔でplant/notificationsを再取得)を追加し、
   アプリを操作せずに置いたままでも、ESP32からの最新値が自動で画面に反映されることを確認。
5. 給電を USB電源から小型モバイルバッテリーに切り替えて動作確認。問題なく動作した
   (要件定義書6章の電源要件を実機で確認できた)。

### 結論

- ENV III分については「センサー → ESP32 → Node.js → SQLite → Flutter」の一気通貫が
  実機・モバイルバッテリー駆動の状態で確認できた。
- 土壌水分(`soil`)は`SOIL_SENSOR_CONNECTED = false`により固定値50を送信している仮の状態。
  照度も未配線のため常に0が送信されている。どちらもセンサー到着後に対応する。

### 今後の対応

- 土壌水分センサー(SEN0308)・照度センサー到着後、`plant_sensor_integrated.ino`の
  `SOIL_SENSOR_CONNECTED`を`true`にし、`readSoilMoisture()`を実測に差し替える。
  照度センサーも配線後、同様にプレースホルダー送信を実測に置き換える。

---

## 2026-08-03: M5Stack Unit Earth (U019) 土壌水分センサー動作確認

### 概要

M5Atom MatrixとM5Stack Unit Earth (U019) を使用し、土壌水分センサーの動作確認を実施した。

### 使用機材

- M5Atom Matrix
- M5Stack Unit Earth (U019)
- Arduino IDE
- M5Stack Board Manager v2.1.3

### 使用したサンプルコード

M5Stack公式サンプルをベースに、ATOM MatrixのGroveポート(GPIO32: Analog / GPIO26: Digital)を使用して動作確認を行った。

## 初期症状

当初はATOM PortABC Base経由で接続していたため、

```
AnalogRead:0
DigitalRead:0
```

となり、正常に値を取得できなかった。
調査の結果、公式サンプルは

```
M5Atom Matrix
↓
Unit Earth（直接接続）
```

を前提としており、PortABC Base経由ではGPIOの割り当てが異なるため正常に動作しないことを確認した。

## 動作確認結果

### ① 空中

```
AnalogRead:4095
DigitalRead:1
```

最大値となることを確認。

### ② 水へ浸した場合

```
AnalogRead:2624
DigitalRead:1
```

空中より約1500程度低下し、水分を検知できることを確認。

### ③ 乾いた砂

```
AnalogRead:3894
DigitalRead:1
```

空中より若干低い値となった。

### ④ 水を含ませた砂

```
AnalogRead:1724
DigitalRead:0
```

大きく値が変化し、デジタル出力もしきい値を超えて0へ変化した。

### ⑤ 実際の植木鉢の土

乾燥した植木鉢へ挿したところ、

```
AnalogRead:4095
DigitalRead:1
```

となり、空中とほぼ同じ値となった。

## 考察

今回の結果より、

- M5Atom Matrixは正常
- Unit Earth (U019) は正常
- ADCによる読み取りは正常
- 水分量に応じた値の変化も確認

できたため、センサーや配線の故障ではないと判断した。
一方で、植木鉢では期待した変化が得られなかった。
Unit Earthは容量式土壌水分センサーであり、水分そのものではなく土壌の誘電率を測定している。
そのため、

- 土の種類
- 土の密度
- 粒径
- 含水状態
- 空気層

などの影響を大きく受ける。
砂では大きな変化が確認できた一方、今回使用した植木鉢の土ではほとんど変化が見られず、土壌の種類によって測定結果が大きく異なることを確認した。

## 結論

M5Stack Unit Earth (U019) は正常に動作していることを確認した。
しかし、本センサーは土壌の種類によって測定値が大きく変化するため、

- どの土でも同じ値になるわけではない
- 使用する土壌ごとのキャリブレーションが必要

であることが分かった。卒業制作では、市販の培養土など対象となる土壌を限定し、

- 乾燥状態
- 適正水分
- 湿潤状態

の基準値を取得したうえで、水分率へ変換する実装が望ましい。

## 今後の対応

- PortABC Base使用時のGPIO割り当てを調査する
- 培養土・黒土・赤玉土など複数の土壌で測定値を比較する
- 土壌ごとのキャリブレーションを検討する
- Flutterアプリ側ではRAW値ではなく水分率(%)へ変換して表示する
- 長期間の測定を行い、経時変化や安定性を評価する
