// 植物見守り: ENV III(温湿度・気圧) + Wi-Fi送信 統合スケッチ
//
// device-test-log.md で「土壌水分センサー(SEN0308)到着後に対応する」と
// 予告していたファイル。土壌水分センサー未着の現段階では、ENV IIIのデータ
// だけを実際にサーバーへ送信し、Flutterアプリまで反映させることを目的とする。
//
// 土壌水分センサーが届いたら SOIL_SENSOR_CONNECTED を true にし、
// readSoilMoisture() の中身を実センサー読み取りに差し替えるだけで済むように
// している(device-test-log.mdに記載のSoilSensorType切り替え方針に対応)。

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

// v1は1台のデバイス・1株のみのため、事前にPOST /plantsで作成した
// 植物のidを固定で指定する(通常は1)。
const int PLANT_ID = 1;

// ---- 土壌水分センサー(未接続時の仮値) ----
// POST /sensor の soil は必須項目(設計書5-4・server/utils/validation.js)。
// センサー未接続のままだとバリデーションエラーになるため、
// SEN0308到着までは「healthy判定になる」仮の固定値を送っておく。
// センサーが届いたら SOIL_SENSOR_CONNECTED を true にし、
// readSoilMoisture() を実際のアナログ読み取りに差し替えること。
const bool SOIL_SENSOR_CONNECTED = false;
const float PLACEHOLDER_SOIL_VALUE = 50.0;

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

float readSoilMoisture() {
  if (!SOIL_SENSOR_CONNECTED) {
    return PLACEHOLDER_SOIL_VALUE;
  }
  // SEN0308到着後、ここを実際のアナログ読み取り+キャリブレーション式に
  // 差し替える(soil_moisture_test.inoでの検証結果を反映する想定)。
  return PLACEHOLDER_SOIL_VALUE;
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
      "\"plant_id\":" + PLANT_ID + "," +
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

  connectWiFi();
  Serial.println("=== 植物見守り: センサー送信開始 ===");
}

void loop() {
  M5.update();

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
  Serial.print("% Soil(placeholder)=");
  Serial.println(soil);

  sendSensorData(temperature, humidity, soil);
}
