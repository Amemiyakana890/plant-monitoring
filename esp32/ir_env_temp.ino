#include <M5Atom.h>
#include <Wire.h>
#include "M5UnitENV.h"   // ライブラリマネージャで "M5Unit-ENV"（M5Stack製）をインストールしてください

// ---- ピン定義 ----
#define IR_PIN 33     // Port B: 赤外線センサー（アナログ入力）
#define ENV_SDA 25    // Port A: I2C SDA（ENVユニット用）※スキャンで確認済み
#define ENV_SCL 21    // Port A: I2C SCL（ENVユニット用）※スキャンで確認済み

// ENV III（SHT30 + QMP6988）用。温度・湿度はSHT30、気圧はQMP6988から取得します。
SHT3X sht30;
QMP6988 qmp6988;

// FastLEDライブラリの設定（CRGB構造体）
CRGB dispColor(uint8_t r, uint8_t g, uint8_t b) {
  return (CRGB)((r << 16) | (g << 8) | b);
}

// LEDマトリクス表示指定配列（0:消灯、1以上：色指定配列で指定した色に指定（color配列1次要素番号））
int matrix0[5][5] = {{0,0,3,3,3},
                    {0,0,3,0,3},
                    {0,0,3,0,3},
                    {0,0,3,0,3},
                    {0,0,3,3,3}};

int matrix1[5][5] = {{0,0,0,3,0},
                      {0,0,3,3,0},
                      {0,0,0,3,0},
                      {0,0,0,3,0},
                      {0,0,3,3,3}}; //十字と4色表示

int matrix2[5][5] = {{0,0,3,3,3},
                    {0,0,0,0,3},
                    {0,0,3,3,3},
                    {0,0,3,0,0},
                    {0,0,3,3,3}};

int matrix3[5][5] = {{0,0,3,3,3},
                    {0,0,0,0,3},
                    {0,0,3,3,3},
                    {0,0,0,0,3},
                    {0,0,3,3,3}};

int matrix4[5][5] = {{0,0,0,3,0},
                    {0,0,3,3,0},
                    {0,3,0,3,0},
                    {0,3,3,3,3},
                    {0,0,0,3,0}};

int matrix5[5][5] = {{0,0,3,3,3},
                    {0,0,3,0,0},
                    {0,0,3,3,3},
                    {0,0,0,0,3},
                    {0,0,3,3,3}};

int matrix6[5][5] = {{0,0,3,3,3},
                    {0,0,3,0,0},
                    {0,0,3,3,3},
                    {0,0,3,0,3},
                    {0,0,3,3,3}};

int matrix7[5][5] = {{0,0,3,3,3},
                    {0,0,0,0,3},
                    {0,0,0,0,3},
                    {0,0,0,0,3},
                    {0,0,0,0,3}};

int matrix8[5][5] = {{0,0,3,3,3},
                    {0,0,3,0,3},
                    {0,0,3,3,3},
                    {0,0,3,0,3},
                    {0,0,3,3,3}};

int matrix9[5][5] = {{0,0,2,2,2},
                    {0,0,2,0,2},
                    {0,0,2,2,2},
                    {0,0,0,0,2},
                    {0,0,2,2,2}};

// 色指定配列（1次要素を色番号として表示する色を2次要素の3原色{赤、緑、青}で設定）
//       LED色： {{0:消灯}  , {1:ピンク}   , {2:オレンジ}  , {3:グリーン} , {4:パープル}  , {5:ホワイト}}
int color[][3] = {{0, 0, 0}, {255, 0, 70}, {255, 70, 0}, {70, 255, 0}, {70, 0, 255}, {255, 255, 255}};

// 変数宣言
int num = 0;   // matrix配列の色番号格納用
int count = 0; // 表示する数字（0～9）

// 反射を検出しているか（触れているか）
bool detected = false;

// 閾値（環境に合わせて調整）
const int THRESHOLD = 1000;

// カウントアップ／温度更新の間隔（ms）
const unsigned long UPDATE_INTERVAL = 1000;

// ENVセンサーの値
float temperature = 0.0;
float humidity = 0.0;
float pressure = 0.0;

// 指定した数字(0～9)をLEDマトリクスに表示する
void showDigit(int d) {
  int localNum = 0;
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
      switch (d) {
        case 0: localNum = matrix0[i][j]; break;
        case 1: localNum = matrix1[i][j]; break;
        case 2: localNum = matrix2[i][j]; break;
        case 3: localNum = matrix3[i][j]; break;
        case 4: localNum = matrix4[i][j]; break;
        case 5: localNum = matrix5[i][j]; break;
        case 6: localNum = matrix6[i][j]; break;
        case 7: localNum = matrix7[i][j]; break;
        case 8: localNum = matrix8[i][j]; break;
        case 9: localNum = matrix9[i][j]; break;
      }
      M5.dis.drawpix(i * 5 + j, dispColor(color[localNum][0], color[localNum][1], color[localNum][2]));
    }
  }
}

void setup()
{
    M5.begin(false, false, true); // 本体初期化（UART, I2C, LED）

    Serial.begin(115200);

    pinMode(IR_PIN, INPUT);

    // Port A（ENVユニット）のI2C初期化とセンサー起動
    // ※ begin()関数の内部でI2C(Wire)も初期化されます
    if (!qmp6988.begin(&Wire, QMP6988_SLAVE_ADDRESS_L, ENV_SDA, ENV_SCL, 400000U)) {
        Serial.println("QMP6988（気圧センサー）が見つかりません。配線を確認してください。");
    }
    if (!sht30.begin(&Wire, SHT3X_I2C_ADDR, ENV_SDA, ENV_SCL, 400000U)) {
        Serial.println("SHT30（温湿度センサー）が見つかりません。配線を確認してください。");
    }

    Serial.println("=== 近接カウンター＆温度表示 ===");
}

void loop()
{
    int sensorValue = analogRead(IR_PIN);
    detected = (sensorValue < THRESHOLD);
    // 上の不等号を逆にするとセンサーを触れている間だけ動きます

    M5.update();   // ←重要

    if (detected) {
        // ---- センサーに触れている間：ENVから温度を取得して表示 ----
        if (sht30.update()) {   // trueが返れば取得成功
            temperature = sht30.cTemp;
            humidity = sht30.humidity;
        }
        if (qmp6988.update()) {
            pressure = qmp6988.pressure / 100.0; // Pa → hPa換算
        }

        // LEDマトリクスは0～9の数字しか表示できないため、
        // 温度の整数部分の下1桁をマトリクスに表示する
        int tempInt = (int)round(temperature);
        int dispDigit = ((tempInt % 10) + 10) % 10; // 負数対策
        showDigit(dispDigit);

        Serial.print("Temp = ");
        Serial.print(temperature);
        Serial.print(" C, Humidity = ");
        Serial.print(humidity);
        Serial.print(" %, Pressure = ");
        Serial.print(pressure);
        Serial.println(" hPa");
    } else {
        // ---- センサーに触れていない間：これまで通りカウントアップ表示 ----
        showDigit(count);

        Serial.print("IR Value = ");
        Serial.print(sensorValue);
        Serial.print("  Detected = false");
        Serial.print("  Count = ");
        Serial.println(count);

        count++;
        if (count > 9) {
            count = 0; // 0～9でループ
        }
    }

    delay(UPDATE_INTERVAL);
}
