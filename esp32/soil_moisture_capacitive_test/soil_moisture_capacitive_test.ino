/*
 * soil_moisture_capacitive_test.ino
 *
 * DFRobot Gravity 防水静電容量式土壌水分センサー V2.0 (SEN0308) 検証スケッチ
 *
 * 【経緯】
 * 当初使用していたM5Stack用土壌水分センサユニット(Unit Earth, U019, 抵抗式)は、
 * 接触不良(数十ms単位でraw値が0〜4095間で暴れる)と用途不一致(防錆・防水加工なし)
 * により使用を中止し、SEN0308(静電容量式)へ変更した。
 * 詳細: docs/device-test-log.md「2026-07-25: 土壌水分センサー接続テスト」を参照。
 *
 * 【本スケッチの目的】
 *  1. 接続の安定性確認(U019と同じ手法でmin/maxのブレを確認する)
 *  2. 空気中(乾燥)・水中(湿潤)でのRAW値を実測し、キャリブレーション値を得る
 *  3. RAW→% 変換とステータスLED表示(green/orange/red)の動作確認
 *
 * 【配線】
 *  ATOM Matrix + ATOM PortABC拡張ベース
 *  Port B (HY2.0-4P, Groveケーブル) → SEN0308
 *  読み取りピン: GPIO33 (Port Bのアナログ出力。U019検証時と同じピンを踏襲)
 *
 * 【注意】
 *  SEN0308の動作電圧は3.3V/5V両対応だが、ESP32のADC入力は3.3V系であることを確認の上、
 *  必ず3.3V駆動で接続すること(U019検証時にPort Bで過電圧疑い事象が発生したため)。
 *
 * 【使い方】
 *  1. MODE_STABILITY_CHECK でしばらく実行し、min/maxの開きが小さいことを確認する
 *     (U019のときのように min=32, max=2042 のような暴れがあれば接続不良を疑う)
 *  2. 安定していたら MODE_CALIBRATION に切り替え、
 *     - センサーを完全に乾いた状態(空気中)にしてRAW値をメモ → SOIL_RAW_DRYに設定
 *     - センサーを水に浸してRAW値をメモ → SOIL_RAW_WETに設定
 *  3. 両方の値を下記の定数に反映したら MODE_NORMAL に切り替えて、
 *     %表示とLEDのステータス切り替えが正しく動くか確認する
 *  4. 確認後、plant_sensor_integrated.ino の SOIL_SENSOR_CONNECTED / readSoilMoisture()
 *     に同じロジックを反映する
 */

#include <M5Atom.h>

// ---------------------------------------------------------------------------
// 設定
// ---------------------------------------------------------------------------

// 動作モードを切り替える(用途に応じて書き換えてから書き込む)
enum TestMode {
  MODE_STABILITY_CHECK,  // 接触不良の切り分け(min/max表示)
  MODE_CALIBRATION,      // 乾燥/湿潤のRAW値を確認する
  MODE_NORMAL            // RAW→%変換 + LEDステータス確認
};

const TestMode CURRENT_MODE = MODE_STABILITY_CHECK;

const int PIN_SOIL = 33;        // Port B アナログ入力
const int SAMPLE_COUNT = 10;    // 1回の読み取りで取得するサンプル数
const int SAMPLE_INTERVAL_MS = 5;   // サンプル間隔(ms)
const int LOOP_INTERVAL_MS = 1000;  // 表示更新間隔(ms)

// キャリブレーション値(2026-08-02 実測。空気中/水中で計測)
// この個体は WET(水中) > DRY(空気中) という結果だった(センサー本体のDRY/MOIST/WET
// 表記の挙動とも一致)。map()は数値の大小に関係なく線形補間するため、
// DRY < WET のままこの2値を渡せばそのまま正しく0〜100%に変換される。
// ※ DRY-WET差が49と小さいため、実際の土でもテストして違和感がないか確認すること。
int SOIL_RAW_DRY = 702;  // 空気中(乾燥)での実測値
int SOIL_RAW_WET = 751;  // 水に浸けた状態での実測値

// 安定性チェックで「異常なブレ」とみなす閾値(U019検証時の暴れ幅を参考に設定)
const int UNSTABLE_DIFF_THRESHOLD = 300;

// ---------------------------------------------------------------------------
// LEDステータス(緑:正常 / 橙:注意 / 赤:エラー)
// ---------------------------------------------------------------------------

void setStatusLED(uint8_t r, uint8_t g, uint8_t b) {
  M5.dis.drawpix(0, CRGB(r, g, b));
}

void setStatusOK() {
  setStatusLED(0, 40, 0);       // 緑
}

void setStatusWarning() {
  setStatusLED(60, 30, 0);      // 橙
}

void setStatusError() {
  setStatusLED(60, 0, 0);       // 赤
}

// ---------------------------------------------------------------------------
// センサー読み取り
// ---------------------------------------------------------------------------
//
// 注意: Arduino IDEはビルド時に関数プロトタイプを自動生成し、includeの直後に
// 挿入する。この挿入位置が独自struct定義より前になってしまい、struct型を
// 戻り値に使うと「型が分からない」というコンパイルエラーになることがある。
// これを避けるため、結果はstruct/戻り値ではなくグローバル変数に格納する。

int soilRawAvg = 0;
int soilRawMin = 0;
int soilRawMax = 0;

void readSoilRawStats() {
  int minVal = 4095;
  int maxVal = 0;
  long sum = 0;

  for (int i = 0; i < SAMPLE_COUNT; i++) {
    int raw = analogRead(PIN_SOIL);
    sum += raw;
    if (raw < minVal) minVal = raw;
    if (raw > maxVal) maxVal = raw;
    delay(SAMPLE_INTERVAL_MS);
  }

  soilRawAvg = sum / SAMPLE_COUNT;
  soilRawMin = minVal;
  soilRawMax = maxVal;
}

// RAW値を0〜100%に変換する(キャリブレーション値が未設定の場合は-1を返す)
int rawToPercent(int raw) {
  if (SOIL_RAW_DRY == 0 && SOIL_RAW_WET == 0) {
    return -1;  // 未キャリブレーション
  }

  // map()はSOIL_RAW_DRY/SOIL_RAW_WETの大小に関わらず線形補間するため、
  // 実測したDRY/WETの値をそのまま渡せばよい(向きの入れ替えは不要)。
  int percent = map(raw, SOIL_RAW_DRY, SOIL_RAW_WET, 0, 100);
  percent = constrain(percent, 0, 100);
  return percent;
}

// ---------------------------------------------------------------------------
// setup / loop
// ---------------------------------------------------------------------------

void setup() {
  M5.begin(true, false, true);  // Serial, I2C無効, LED有効
  delay(50);

  pinMode(PIN_SOIL, INPUT);

  Serial.println();
  Serial.println("=== SEN0308 (静電容量式土壌水分センサー) 検証スケッチ ===");

  switch (CURRENT_MODE) {
    case MODE_STABILITY_CHECK:
      Serial.println("[MODE] 安定性チェック: min/maxのブレを確認してください");
      break;
    case MODE_CALIBRATION:
      Serial.println("[MODE] キャリブレーション: 空気中/水中でRAW値をメモしてください");
      break;
    case MODE_NORMAL:
      Serial.println("[MODE] 通常動作確認: RAW→%変換とLEDステータスを確認します");
      if (SOIL_RAW_DRY == 0 && SOIL_RAW_WET == 0) {
        Serial.println("[WARN] SOIL_RAW_DRY / SOIL_RAW_WET が未設定です。先にMODE_CALIBRATIONで実測してください。");
      }
      break;
  }

  setStatusOK();
}

void loop() {
  readSoilRawStats();  // 結果は soilRawAvg / soilRawMin / soilRawMax に入る
  int diff = soilRawMax - soilRawMin;

  switch (CURRENT_MODE) {
    case MODE_STABILITY_CHECK: {
      Serial.printf(
        "avg=%d  min=%d  max=%d  diff=%d%s\n",
        soilRawAvg, soilRawMin, soilRawMax, diff,
        (diff >= UNSTABLE_DIFF_THRESHOLD) ? "  <-- 接触不良の疑いあり" : ""
      );

      if (diff >= UNSTABLE_DIFF_THRESHOLD) {
        setStatusError();
      } else {
        setStatusOK();
      }
      break;
    }

    case MODE_CALIBRATION: {
      Serial.printf(
        "RAW avg=%d (min=%d / max=%d)  ※乾燥/水中それぞれでこの値をメモする\n",
        soilRawAvg, soilRawMin, soilRawMax
      );
      setStatusWarning();  // キャリブレーション中は橙で表示
      break;
    }

    case MODE_NORMAL: {
      int percent = rawToPercent(soilRawAvg);

      if (percent < 0) {
        Serial.printf("RAW avg=%d  -> %%変換不可(未キャリブレーション)\n", soilRawAvg);
        setStatusWarning();
      } else {
        Serial.printf("RAW avg=%d  -> soil=%d%%\n", soilRawAvg, percent);

        // system-design.md 5-7の閾値ロジックに合わせた簡易プレビュー
        if (percent >= 40) {
          setStatusOK();       // healthy
        } else if (percent >= 20) {
          setStatusWarning();  // thirsty
        } else {
          setStatusError();    // dry
        }
      }
      break;
    }
  }

  delay(LOOP_INTERVAL_MS);
}
