// 植物見守り: ENV III(温湿度・気圧) + 土壌水分(U019) + 照度(BH1750) + Wi-Fi送信 統合スケッチ
//
// 現在esp32/配下に残す唯一のスケッチ。土壌水分センサーの検証用に存在していた
// soil_moisture_test.ino / soil_moisture_capacitive_test.ino は役目を終えたため、
// リポジトリから削除してよい(検証結果はdocs/device-test-log.mdに記録済み)。
//
// 土壌水分センサーはM5シリーズでの機材統一を優先し、
// M5Stack用 土壌水分センサユニット(Unit Earth, U019, 抵抗式)+砂ポケット運用を採用した
// (docs/device-test-log.md 2026-08-03参照)。
//
// ★配線変更(照度センサー追加に伴うピン再配置、atom_env3_light_test.inoでの検証結果を反映)★
// 照度センサー(BH1750)をI2Cバス2(Wire1, SDA=GPIO26/SCL=GPIO32)に接続したため、
// 土壌水分センサー(GPIO32を使用していた)はATOM PortABC拡張ベースのPort B経由
// (GPIO33)に戻している。
//
// ⚠️注意: Port B経由(GPIO33)は、2026-08-04以前に「RAW値が4090前後
// (ADC最大値付近)に張り付く」異常が発生し、それが原因で本体Grove直挿し
// (GPIO32)に変更した配線である(docs/device-test-log01.md参照)。原因は
// 拡張ベースPort B側の接続(コネクタ・過電圧の可能性)に起因すると推測されて
// おり、GPIO32へ移設したこと自体が対処だったため、今回GPIO33に戻すことで
// 同じ症状が再発する可能性がある。
// 実機投入前に必ずCALIBRATION_MODE = trueで実行し、乾いた状態・湿った状態
// それぞれでRAW値が張り付かず安定して変化することを確認してから
// SOIL_RAW_DRY / SOIL_RAW_WET を実測値で更新すること。
// (再発する場合は、拡張ベースを使わずBH1750側のI2Cピンを別GPIOに
//  変更する配線を再検討する)
//
// 照度センサー(U021想定→実際にはBH1750採用)は本バージョンより接続。
// ENV III(I2C, Wire, Port A: GPIO25/21)とはバスを分離しているため競合しない。

#include <M5Atom.h>
#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "M5UnitENV.h"   // ライブラリマネージャで "M5Unit-ENV"（M5Stack製）をインストール
#include <BH1750.h>      // ライブラリマネージャで "BH1750" をインストール

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
const int DEVICE_ID = 1;

// ---- 土壌水分センサー(M5Stack Unit Earth, U019, 抵抗式) ----
// ★2026-08現在: 照度センサー追加のためPort B経由(GPIO33)に戻した(上記の注意を参照)。
// 砂ポケット運用のため、乾燥時/湿潤時のRAW値は必ず実機・実際の砂で
// 実測してから SOIL_RAW_DRY / SOIL_RAW_WET を書き換えること。
// 下記はGPIO32(本体Grove直挿し)構成時の実測値であり、GPIO33(Port B)に
// 戻した現構成ではそのまま使えない可能性が高い。再キャリブレーション必須。
#define SOIL_PIN 33
int SOIL_RAW_DRY = 3745;  // TODO: Port B(GPIO33)構成で再実測して置き換えること
int SOIL_RAW_WET = 2020;  // TODO: 同上

// ---- キャリブレーションモード ----
// true にして書き込むと、Wi-Fi送信は行わずシリアルモニタにRAW値のみを
// 1秒おきに表示する(旧soil_moisture_test.inoの安定性チェックモード相当)。
// 配線変更(Port B/GPIO33への回帰)直後は、必ずこのモードで
// 「ADC最大値付近に張り付かず、乾湿で値がなめらかに変化するか」を
// 確認してから false に戻すこと(device-test-log01.mdの再発チェック)。
const bool CALIBRATION_MODE = false;

// ---- ENV III(I2C バス1, Port A) ----
#define ENV_SDA 25
#define ENV_SCL 21
SHT3X sht30;
QMP6988 qmp6988;

// ---- 照度センサー BH1750(I2C バス2, Wire1) ----
// atom_env3_light_test.ino での検証結果を反映(SDA=GPIO26 / SCL=GPIO32)。
// ENV IIIとは別バス(Wire1)にすることでI2Cアドレス衝突・配線競合を避けている。
#define LIGHT_SDA 26
#define LIGHT_SCL 32
BH1750 lightMeter;
bool bh1750Ok = false;

// 送信間隔(ms)。実運用ではセンサー突然死や電池消費とのバランスで調整する。
const unsigned long SEND_INTERVAL = 30000;
unsigned long lastSendMillis = 0;

// LEDマトリクスで送信結果をひと目で確認できるようにする
// (README/設計書のステータスLED方針: 緑=正常/橙=注意/赤=エラー を流用。
//  ただし赤は「点灯(dry要ケア)」と「点滅(通信エラー)」で意味を分けている。
//  詳細はblinkError()のコメント参照)
CRGB dispColor(uint8_t r, uint8_t g, uint8_t b) {
  return (CRGB)((r << 16) | (g << 8) | b);
}
void showStatusColor(uint8_t r, uint8_t g, uint8_t b) {
  for (int i = 0; i < 25; i++) {
    M5.dis.drawpix(i, dispColor(r, g, b));
  }
}

// 「赤の点灯(土壌水分dry=要ケア、通信自体は正常)」と
// 「赤の点滅(Wi-Fi未接続・サーバーエラー等の通信トラブル)」を区別するための
// エラー専用表示。以前は両方とも赤の点灯だったため、「乾燥で赤く光っている
// だけなのにエラーだと勘違いした」という紛らわしさがあった経緯を踏まえて分離した。
// delay()でブロッキングするが、エラー通知時のみ・1回あたり3回点滅(計1.8秒)程度なので
// センサー送信間隔(30秒〜本番10分)に対して影響は無視できる。
void blinkError() {
  const int blinkCount = 3;
  for (int i = 0; i < blinkCount; i++) {
    showStatusColor(255, 0, 0);
    delay(300);
    showStatusColor(0, 0, 0); // 消灯
    delay(300);
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
// illuminanceは読み取りに失敗した場合(hasIlluminance=false)、サーバー側の
// バリデーション(server/utils/validation.js)が任意項目扱いのため、
// JSONのフィールド自体を省略して送信する(0luxとして誤認識させないため)。
bool sendSensorData(float temperature, float humidity, float soil,
                     bool hasIlluminance, float illuminance) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi未接続のため送信をスキップしました");
    blinkError();
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
      "\"soil\":" + String(soil, 1);
  if (hasIlluminance) {
    payload += String(",\"illuminance\":") + String(illuminance, 1);
  }
  payload += "}";

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
      showStatusColor(255, 0, 0);       // 赤の点灯: 乾燥(要ケア。通信自体は正常)
    } else if (responseBody.indexOf("\"thirsty\"") != -1) {
      showStatusColor(255, 140, 0);     // 橙: 注意
    } else {
      showStatusColor(0, 200, 0);       // 緑: 正常
    }
    return true;
  }

  // 通信エラー(サーバー未応答・404・500等)は「赤の点滅」で、
  // 土壌水分dry(赤の点灯)と見分けられるようにする。
  blinkError();
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

  // 照度センサー(BH1750)はENV IIIと別のI2Cバス(Wire1)で初期化する。
  Wire1.begin(LIGHT_SDA, LIGHT_SCL);
  Wire1.setClock(100000);
  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE, 0x23, &Wire1)) {
    bh1750Ok = true;
    Serial.println("BH1750（照度センサー）を検出しました。");
  } else {
    Serial.println("BH1750（照度センサー）が見つかりません。配線を確認してください。");
  }

  pinMode(SOIL_PIN, INPUT);
  // Port B(GPIO33)はESP32のADC2系。Wi-Fi使用中はADC2の精度が不安定になる
  // ことがある点に注意(GPIO32/ADC1系だった旧配線ではこの制約がなかった)。
  // CALIBRATION_MODEでの再検証時、Wi-Fi接続前後で値が変わらないかも
  // 併せて確認すること。
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);

  if (CALIBRATION_MODE) {
    Serial.println("=== 土壌水分センサー(U019) キャリブレーションモード ===");
    Serial.println("乾いた砂・湿った砂でそれぞれRAW値が安定するか確認してください。");
    Serial.println("(Port B/GPIO33への配線変更後の再検証が必須です)");
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

  bool hasIlluminance = false;
  float illuminance = 0.0;
  if (bh1750Ok) {
    float lux = lightMeter.readLightLevel();
    if (lux >= 0) {
      illuminance = lux;
      hasIlluminance = true;
    } else {
      Serial.println("BH1750（照度センサー）の読み取りに失敗しました");
    }
  }

  Serial.print("Temp=");
  Serial.print(temperature);
  Serial.print("C Humidity=");
  Serial.print(humidity);
  Serial.print("% Soil=");
  Serial.print(soil);
  Serial.print("%");
  if (hasIlluminance) {
    Serial.print(" Illuminance=");
    Serial.print(illuminance);
    Serial.print("lx");
  }
  Serial.println();

  sendSensorData(temperature, humidity, soil, hasIlluminance, illuminance);
}
