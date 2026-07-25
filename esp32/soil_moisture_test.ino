#include <M5Atom.h>
#include <Wire.h>
#include "M5UnitENV.h"   // ライブラリマネージャで "M5Unit-ENV"（M5Stack製）をインストールしてください

// =====================================================================
// 「植物見守り」センサーデバイス 統合テストスケッチ
//
// ENV Ⅲ(温度・湿度・気圧)と土壌水分センサーを1本のスケッチにまとめたもの。
// 参考にした記事( https://nouka-it.hatenablog.com/entry/2022/02/14/221618 )は
// M5Stack Core(LCD画面あり)向けのため、そのままは使えなかった。
// ATOM Matrixには画面がないため、画面表示の代わりにLEDマトリクスの色で
// 状態を示す設計にしている(表示自体はスマホアプリ側の役割、企画書2章)。
//
// まだWi-Fi送信は実装していない。ここではセンサー統合と状態判定の
// 動作確認までを行い、確認できたらPOST /sensor送信を追加する。
// =====================================================================

// ---- ピン定義 ----
#define ENV_SDA 25   // Port A: I2C SDA(ENVユニット用)※スキャンで確認済み
#define ENV_SCL 21   // Port A: I2C SCL(ENVユニット用)※スキャンで確認済み

// 【重要】土壌水分センサーは種類によって配線もrawの向きも異なるため、
// どちらを使うかをここで切り替えられるようにしている。
//   EARTH_RESISTIVE   : M5Stack Unit Earth(U019、抵抗式)
//                       → 拡張ベースのPort B(HY2.0-4P)にそのまま挿す。GPIO33が実績あり。
//                       → 乾燥=低い値、湿潤=高い値。
//   CAPACITIVE_SEN0308: DFRobot SEN0308(静電容量式、届き次第切り替え)
//                       → Port Bには挿せないため、VCC→3.3V、GND→GND、SIG→GPIO33 と直接配線。
//                       → 乾燥=高い値、湿潤=低い値(Unit Earthと逆)。
enum SoilSensorType { EARTH_RESISTIVE, CAPACITIVE_SEN0308 };
const SoilSensorType SOIL_SENSOR_TYPE = EARTH_RESISTIVE;

#define SOIL_PIN 33

// 今回はUnit Earthを接続して試すため true にする。
// 何も繋がっていない/配線していない間は false にしておくこと。
const bool SOIL_SENSOR_CONNECTED = true;

// ---- ENV III(SHT30 + QMP6988) ----
SHT3X sht30;
QMP6988 qmp6988;
bool envAvailable = false; // 起動時にセンサーが見つかったかどうか

// ---- 土壌水分センサー ----
const int SAMPLE_COUNT = 10; // ノイズ対策の平均回数

// ---- キャリブレーション用の生値(実測して書き換える) ----
// 使い方: 今使っているセンサー用のテストスケッチ
//   (EARTH_RESISTIVE      → soil_moisture_test.ino
//    CAPACITIVE_SEN0308   → soil_moisture_capacitive_test.ino)
// で計測した SOIL_RAW_DRY / SOIL_RAW_WET をそのままここに転記する。
// センサーを切り替えたら必ず取り直すこと(向きも生値の範囲も別物のため)。
const int SOIL_RAW_DRY = -1; // 未計測(-1のままなら soilPercent は 0 になる)
const int SOIL_RAW_WET = -1; // 未計測

// センサー読み取り・表示の間隔(ms)
const unsigned long UPDATE_INTERVAL = 2000;

// LED色(0xRRGGBB)。植物ステータス(設計書5-7)と対応させている。
const uint32_t COLOR_HEALTHY = 0x00ff00; // healthy: soil >= 40
const uint32_t COLOR_THIRSTY = 0xffa000; // thirsty: 20 <= soil < 40
const uint32_t COLOR_DRY     = 0xff0000; // dry:     soil < 20
const uint32_t COLOR_UNKNOWN = 0x404040; // キャリブレーション未実施などで判定不能

// 直近のセンサー値(あとでPOST /sensor送信に使う想定なのでグローバルに保持)
float temperature = 0.0;
float humidity = 0.0;
float pressure = 0.0;
int soilRaw = 0;
float soilPercent = 0.0; // 0〜100(未キャリブレーション時は0)

int readSoilRawAveraged() {
  long sum = 0;
  for (int i = 0; i < SAMPLE_COUNT; i++) {
    sum += analogRead(SOIL_PIN);
    delay(5);
  }
  return sum / SAMPLE_COUNT;
}

// 生値を0〜100%に変換する。センサーの種類によって「乾燥/湿潤どちらが
// 高い値になるか」が逆なので、SOIL_SENSOR_TYPE に応じて分子分母を入れ替える。
float soilRawToPercent(int raw) {
  if (SOIL_RAW_DRY < 0 || SOIL_RAW_WET < 0 || SOIL_RAW_DRY == SOIL_RAW_WET) {
    return 0.0; // 未キャリブレーション
  }
  float percent;
  if (SOIL_SENSOR_TYPE == EARTH_RESISTIVE) {
    // 抵抗式: 湿潤 = 高い値
    percent = 100.0 * (raw - SOIL_RAW_DRY) / (float)(SOIL_RAW_WET - SOIL_RAW_DRY);
  } else {
    // 静電容量式(SEN0308): 乾燥 = 高い値
    percent = 100.0 * (SOIL_RAW_DRY - raw) / (float)(SOIL_RAW_DRY - SOIL_RAW_WET);
  }
  return constrain(percent, 0.0, 100.0);
}

// 設計書5-7・server/utils/plantStatus.jsと同じ閾値。
// サーバー側の判定ロジックと食い違わないよう、変更する場合は両方揃えること。
const char* determineStatus(float soil) {
  if (soil >= 40) return "healthy";
  if (soil >= 20) return "thirsty";
  return "dry";
}

uint32_t colorForStatus(const char* status, bool calibrated) {
  if (!calibrated) return COLOR_UNKNOWN;
  if (strcmp(status, "healthy") == 0) return COLOR_HEALTHY;
  if (strcmp(status, "thirsty") == 0) return COLOR_THIRSTY;
  return COLOR_DRY;
}

void setup() {
  M5.begin(false, false, true); // 本体初期化(UART, I2C, LED)
  Serial.begin(115200);

  if (SOIL_SENSOR_CONNECTED) {
    pinMode(SOIL_PIN, INPUT);
  }

  // Port A(ENVユニット)のI2C初期化とセンサー起動
  bool qmpOk = qmp6988.begin(&Wire, QMP6988_SLAVE_ADDRESS_L, ENV_SDA, ENV_SCL, 400000U);
  bool shtOk = sht30.begin(&Wire, SHT3X_I2C_ADDR, ENV_SDA, ENV_SCL, 400000U);
  envAvailable = qmpOk && shtOk;

  if (!qmpOk) Serial.println("QMP6988(気圧センサー)が見つかりません。配線を確認してください。");
  if (!shtOk) Serial.println("SHT30(温湿度センサー)が見つかりません。配線を確認してください。");

  Serial.println("=== 植物見守り センサー統合テスト ===");
  if (!SOIL_SENSOR_CONNECTED) {
    Serial.println("※ 土壌水分センサーは未接続として扱っています(SOIL_SENSOR_CONNECTED = false)。");
  } else if (SOIL_RAW_DRY < 0 || SOIL_RAW_WET < 0) {
    Serial.println("※ 土壌水分センサーは未キャリブレーションです(SOIL_RAW_DRY/WETが未設定)。");
  }
}

void loop() {
  M5.update();

  if (envAvailable) {
    if (sht30.update()) {
      temperature = sht30.cTemp;
      humidity = sht30.humidity;
    }
    if (qmp6988.update()) {
      pressure = qmp6988.pressure / 100.0; // Pa → hPa換算
    }
  }

  if (SOIL_SENSOR_CONNECTED) {
    soilRaw = readSoilRawAveraged();
    soilPercent = soilRawToPercent(soilRaw);
  }
  bool calibrated = SOIL_SENSOR_CONNECTED &&
      (SOIL_RAW_DRY >= 0 && SOIL_RAW_WET >= 0 && SOIL_RAW_DRY != SOIL_RAW_WET);
  const char* status = calibrated ? determineStatus(soilPercent) : "unknown";

  Serial.print("Temp = ");
  Serial.print(temperature);
  Serial.print(" C, Humidity = ");
  Serial.print(humidity);
  Serial.print(" %, Pressure = ");
  Serial.print(pressure);
  Serial.print(" hPa, Soil = ");
  if (SOIL_SENSOR_CONNECTED) {
    Serial.print("raw ");
    Serial.print(soilRaw);
    Serial.print(" / ");
    Serial.print(soilPercent, 1);
    Serial.print(" % (");
    Serial.print(status);
    Serial.println(")");
  } else {
    Serial.println("未接続");
  }

  M5.dis.fillpix(colorForStatus(status, calibrated));

  delay(UPDATE_INTERVAL);
}
