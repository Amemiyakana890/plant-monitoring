// 植物見守り: ENV III(温湿度・気圧) + 土壌水分(U019) + Wi-Fi送信 統合スケッチ
//
// 現在esp32/配下に残す唯一のスケッチ。土壌水分センサーの検証用に存在していた
// soil_moisture_test.ino / soil_moisture_capacitive_test.ino は役目を終えたため、
// リポジトリから削除してよい(検証結果はdocs/device-test-log.mdに記録済み)。
//
// 土壌水分センサーはM5シリーズでの機材統一を優先し、
// M5Stack用 土壌水分センサユニット(Unit Earth, U019, 抵抗式)+砂ポケット運用を採用した
// (docs/device-test-log.md 2026-08-03参照)。
// 配線はATOM PortABC拡張ベースのPort B経由(GPIO33)からATOM Matrix本体の
// Groveポート直挿し(GPIO32)に変更している(PortB経由でRAW値が異常に張り付く
// 現象が発生したため。詳細は追記予定のdevice-test-logエントリを参照)。
//
// 照度センサー(U021)は現バージョンでは未接続。
// ENV III(I2C、拡張ベースPort A)との競合懸念、およびATOM MatrixのI2C使用により
// ピンに空きがない可能性が高いため、当面はENV III(拡張ベースPort A)+
// U019(本体Grove直挿し)の2センサー構成で進める。
// (照度を追加する場合は配線方式の再検討が必要。詳細はdevice-test-log.mdに追記予定)

#include <M5Atom.h>
#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "M5UnitENV.h"   // ライブラリマネージャで "M5Unit-ENV"（M5Stack製）をインストール

// ---- Wi-Fi・サーバー設定 ----
// SSID・パスワード・サーバーIPはGit管理対象外の secrets.h に分離している
// (.env と同じ考え方。詳細は secrets.h.example のコメント参照)。
// 初回のみ、このファイルと同じフォルダで以下を実行してから値を書き換えること。
//   cp secrets.h.example secrets.h   (Windowsは copy secrets.h.example secrets.h)
#include "secrets.h"

const int SERVER_PORT = 3000;
const char* SENSOR_ENDPOINT = "/api/sensor";

// デバイスペアリング機能の実装に伴い、plant_idの直接指定から
// device_id起点(設計書5-4)に戻した。事前にPOST /devices/pairで
// このデバイスを登録し、払い出されたidをここに設定する
// (登録したデバイスは別途PATCH /plants/:idで植物と紐付けておくこと)。
const int DEVICE_ID = 3;

// ---- 土壌水分センサー(M5Stack Unit Earth, U019, 抵抗式) ----
// 当初はATOM PortABC拡張ベースのPort B経由(GPIO33)で接続していたが、
// RAW値が4090前後(ADC最大値4095付近)に張り付く現象が発生し、
// 7/25の検証ログと同様の「過電圧/接触不良」の疑いがあったため、
// ATOM Matrix本体のGroveポートへの直挿し(GPIO32、ADC1系)に変更した。
// GPIO32はENV IIIが使うI2Cピン(GPIO25/21)と競合せず、
// Wi-Fi動作中でも安定して読み取れる。
// 砂ポケット運用のため、乾燥時/湿潤時のRAW値は必ず実機・実際の砂で
// 実測してから SOIL_RAW_DRY / SOIL_RAW_WET を書き換えること。
// 下記は2026-08-04に本体Grove直挿し(GPIO32)構成で実測した値
// (乾いた土:3791/3806/3739/3747/3641の平均、加水後の土:2096/2022/1922/2006/2037/2039の平均)。
// このセンサー・配線の組み合わせでは「乾燥時=高いRAW値、湿潤時=低いRAW値」という、
// 一般的な想定(乾燥時=低い/湿潤時=高い)とは逆の向きになることが分かった。
// 式は (raw - DRY) / (WET - DRY) * 100 なので、大小関係が逆でも
// DRY/WETに実測値を正しく入れれば0〜100%に正常変換される。
// なお今回の実測は「土」で行っており、実際の運用(砂ポケット)とは
// 計測対象が異なる点に注意。砂での運用に切り替えた際は再実測が望ましい。
#define SOIL_PIN 32
int SOIL_RAW_DRY = 3745;
int SOIL_RAW_WET = 2020;

// ---- キャリブレーションモード ----
// true にして書き込むと、Wi-Fi送信は行わずシリアルモニタにRAW値のみを
// 1秒おきに表示する(旧soil_moisture_test.inoの安定性チェックモード相当)。
// 乾いた砂・湿った砂それぞれで数値が安定するのを確認し、
// 上記 SOIL_RAW_DRY / SOIL_RAW_WET を実測値に更新したら、
// 必ず false に戻してから通常運用すること。
const bool CALIBRATION_MODE = false;

// ---- ENV III(I2C, Port A) ----
#define ENV_SDA 25
#define ENV_SCL 21
SHT3X sht30;
QMP6988 qmp6988;

// 送信間隔(ms)。実運用ではセンサー突然死や電池消費とのバランスで調整する。
const unsigned long SEND_INTERVAL = 30000;
unsigned long lastSendMillis = 0;

// LEDマトリクスで送信結果をひと目で確認できるようにする
// (README/設計書のステータスLED方針: 緑=正常/橙=注意/赤=エラー を流用)
CRGB dispColor(uint8_t r, uint8_t g, uint8_t b) {
  return (CRGB)((r << 16) | (g << 8) | b);
}
void showStatusColor(uint8_t r, uint8_t g, uint8_t b) {
  for (int i = 0; i < 25; i++) {
    M5.dis.drawpix(i, dispColor(r, g, b));
  }
}

// U019のRAW値を0〜100%のsoil値に変換する。
// SOIL_RAW_DRY/WETが未実測(暫定値)のままだと精度は保証されないため、
// 必ずキャリブレーション後の値を使うこと。
float readSoilMoisture() {
  int raw = analogRead(SOIL_PIN);

  if (SOIL_RAW_DRY == SOIL_RAW_WET) {
    return 0.0; // ゼロ除算防止(未設定時のフェイルセーフ)
  }

  float percent = (float)(raw - SOIL_RAW_DRY) /
                  (float)(SOIL_RAW_WET - SOIL_RAW_DRY) * 100.0;
  return constrain(percent, 0.0, 100.0);
}

void connectWiFi() {
  Serial.print("Wi-Fi接続中");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Wi-Fi接続完了。IP: ");
  Serial.println(WiFi.localIP());
}

// センサー値をJSONにしてPOST /sensorへ送信する。
// ArduinoJsonライブラリを追加せず、項目数が少ないため文字列組み立てで済ませる。
bool sendSensorData(float temperature, float humidity, float soil) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi未接続のため送信をスキップしました");
    return false;
  }

  HTTPClient http;
  String url =
      String("http://") + SERVER_HOST + ":" + SERVER_PORT + SENSOR_ENDPOINT;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  String payload = String("{") +
      "\"device_id\":" + DEVICE_ID + "," +
      "\"temperature\":" + String(temperature, 1) + "," +
      "\"humidity\":" + String(humidity, 1) + "," +
      "\"soil\":" + String(soil, 1) +
      "}";

  int statusCode = http.POST(payload);
  String responseBody = http.getString();
  http.end();

  Serial.print("POST /sensor -> HTTP ");
  Serial.print(statusCode);
  Serial.print(" : ");
  Serial.println(responseBody);

  if (statusCode == 201) {
    // レスポンス例: {"plant_id":1,"status":"healthy"}
    if (responseBody.indexOf("\"dry\"") != -1) {
      showStatusColor(255, 0, 0);       // 赤: 乾燥(要ケア)
    } else if (responseBody.indexOf("\"thirsty\"") != -1) {
      showStatusColor(255, 140, 0);     // 橙: 注意
    } else {
      showStatusColor(0, 200, 0);       // 緑: 正常
    }
    return true;
  }

  showStatusColor(255, 0, 0); // 通信エラーも赤で分かるようにする
  return false;
}

void setup() {
  M5.begin(false, false, true);
  Serial.begin(115200);

  if (!qmp6988.begin(&Wire, QMP6988_SLAVE_ADDRESS_L, ENV_SDA, ENV_SCL, 400000U)) {
    Serial.println("QMP6988（気圧センサー）が見つかりません。配線を確認してください。");
  }
  if (!sht30.begin(&Wire, SHT3X_I2C_ADDR, ENV_SDA, ENV_SCL, 400000U)) {
    Serial.println("SHT30（温湿度センサー）が見つかりません。配線を確認してください。");
  }

  pinMode(SOIL_PIN, INPUT);

  if (CALIBRATION_MODE) {
    Serial.println("=== 土壌水分センサー(U019) キャリブレーションモード ===");
    Serial.println("乾いた砂・湿った砂でそれぞれRAW値が安定するか確認してください。");
    return; // Wi-Fi接続は行わない
  }

  connectWiFi();
  Serial.println("=== 植物見守り: センサー送信開始 ===");
}

void loop() {
  M5.update();

  if (CALIBRATION_MODE) {
    int raw = analogRead(SOIL_PIN);
    Serial.print("[CALIBRATION] Soil RAW = ");
    Serial.println(raw);
    delay(1000);
    return;
  }

  unsigned long now = millis();
  if (now - lastSendMillis < SEND_INTERVAL && lastSendMillis != 0) {
    return;
  }
  lastSendMillis = now;

  float temperature = 0.0;
  float humidity = 0.0;

  if (sht30.update()) {
    temperature = sht30.cTemp;
    humidity = sht30.humidity;
  } else {
    Serial.println("ENV III（SHT30）の読み取りに失敗しました");
  }

  float soil = readSoilMoisture();

  Serial.print("Temp=");
  Serial.print(temperature);
  Serial.print("C Humidity=");
  Serial.print(humidity);
  Serial.print("% Soil=");
  Serial.print(soil);
  Serial.println("%");

  sendSensorData(temperature, humidity, soil);
}
