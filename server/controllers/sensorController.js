import db from '../database/db.js';
import {
  determineStatus,
  resolveTemperatureStatus,
  classifyHumidityDailyAverage,
  classifyIlluminanceDailyAverage,
} from '../utils/plantStatus.js';
import { validateSensorPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';
import { toSqliteTimestamp, shouldRunDailyEvaluation } from '../utils/time.js';

// device_idから紐づく植物を1件引く(設計書6章: plants.device_id → devices.id)。
// 設計書5-4本文の「devices.plant_id を参照」という記述は、実際のテーブル定義
// (6章)とは逆向きの記載だったための表記ゆれ。実装は6章のスキーマに合わせる。
const selectPlantByDeviceIdStmt = db.prepare(
  `SELECT * FROM plants WHERE device_id = ?`,
);

const insertLogStmt = db.prepare(
  `INSERT INTO sensor_logs (plant_id, temperature, humidity, soil, illuminance)
   VALUES (?, ?, ?, ?, ?)`,
);

const updateStatusStmt = db.prepare(
  `UPDATE plants SET status = ? WHERE id = ?`,
);

const updateTemperatureStmt = db.prepare(
  `UPDATE plants SET temp_status = ?, temp_out_of_range_since = ? WHERE id = ?`,
);

const updateHumidityDailyStmt = db.prepare(
  `UPDATE plants SET humidity_daily_status = ?, humidity_daily_avg = ?, humidity_evaluated_at = ? WHERE id = ?`,
);

const updateIlluminanceDailyStmt = db.prepare(
  `UPDATE plants SET illuminance_daily_status = ?, illuminance_daily_avg = ?, illuminance_evaluated_at = ? WHERE id = ?`,
);

// 湿度: 直近24時間の単純平均(docs/status-notification-design.md 3-2)。
const selectHumidityDailyAverageStmt = db.prepare(`
  SELECT AVG(humidity) AS avg_value, COUNT(*) AS sample_count
  FROM sensor_logs
  WHERE plant_id = ?
    AND humidity IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
`);

// 照度: 直近24時間のうち「昼間(6:00〜18:00, JST)」だけを抽出して平均する
// (docs/status-notification-design.md 3-4)。
// created_atはUTCで保存されているため(database/db.js参照)、+9時間して
// JSTに補正してから時刻部分を取り出す。日本国内・DST無しを前提に固定オフセット
// としている(将来海外展開する場合は要見直し)。
const selectIlluminanceDaytimeAverageStmt = db.prepare(`
  SELECT AVG(illuminance) AS avg_value, COUNT(*) AS sample_count
  FROM sensor_logs
  WHERE plant_id = ?
    AND illuminance IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
    AND CAST(strftime('%H', created_at, '+9 hours') AS INTEGER) >= 6
    AND CAST(strftime('%H', created_at, '+9 hours') AS INTEGER) < 18
`);

const insertNotificationStmt = db.prepare(
  `INSERT INTO notifications (plant_id, message) VALUES (?, ?)`,
);

// 状態が「悪化した」場合にのみ通知するための順位付け(設計書5-7・F-05)。
// 「静かに見守る」コンセプト上、同じ状態が続く間は毎回通知しない。
// 温度も同じ3段階(healthy/caution/needs_care)の悪化判定を使う
// (docs/status-notification-design.md 6-1〜6-3)。
const SOIL_STATUS_RANK = { healthy: 0, thirsty: 1, dry: 2 };
const LEVEL_RANK = { healthy: 0, caution: 1, needs_care: 2 };

const SOIL_NOTIFICATION_MESSAGE = {
  thirsty: '少し乾いてきました。水やりのタイミングを確認してください',
  dry: '土壌水分が少なくなっています。水やりが必要です',
};

const TEMPERATURE_NOTIFICATION_MESSAGE = {
  caution: '気温が適正範囲(18〜30℃)から外れた状態が30分以上続いています。置き場所を確認してください',
  needs_care: '気温が大きく外れています。植物の置き場所をすぐに見直してください',
};

// 土壌水分の状態がpreviousStatusからnewStatusへ悪化した場合のみ通知を1件作成する。
// (healthy→thirsty、thirsty→dry、healthy→dryのいずれか。改善方向は通知しない)
function maybeCreateSoilNotification(plantId, previousStatus, newStatus) {
  const previousRank = SOIL_STATUS_RANK[previousStatus] ?? 0;
  const newRank = SOIL_STATUS_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return;

  const message = SOIL_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return;

  insertNotificationStmt.run(plantId, message);
}

// 温度の状態がpreviousStatusからnewStatusへ悪化した場合のみ通知を1件作成する
// (docs/status-notification-design.md 6-1: リアルタイム系は「悪化した瞬間のみ」通知)。
function maybeCreateTemperatureNotification(plantId, previousStatus, newStatus) {
  const previousRank = LEVEL_RANK[previousStatus] ?? 0;
  const newRank = LEVEL_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return;

  const message = TEMPERATURE_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return;

  insertNotificationStmt.run(plantId, message);
}

// 湿度・照度の日次レポート(docs 6-5)を評価し、DBを更新する。
// 6-5の最終確定ルール:「その日の評価が要ケアの場合のみ通知する」
// (前回の評価と比較しない。要ケアが続く限り毎日15:00に通知する)。
function runDailyEvaluations(plant, now) {
  if (shouldRunDailyEvaluation(plant.humidity_evaluated_at, now)) {
    const { avg_value: avgHumidity, sample_count: sampleCount } =
      selectHumidityDailyAverageStmt.get(plant.id);

    // 直近24時間に湿度データが1件もない場合はAVGがnullになる。
    // 評価不能なのでevaluated_atも更新せず、次回受信時に再試行する。
    if (avgHumidity !== null && sampleCount > 0) {
      const status = classifyHumidityDailyAverage(avgHumidity);
      updateHumidityDailyStmt.run(
        status,
        avgHumidity,
        toSqliteTimestamp(now),
        plant.id,
      );

      if (status === 'needs_care') {
        const message =
          avgHumidity < 40
            ? `過去24時間の湿度が低めです(平均${avgHumidity.toFixed(0)}%)。乾燥に注意してください`
            : `過去24時間の湿度が高めです(平均${avgHumidity.toFixed(0)}%)。蒸れ・カビに注意してください`;
        insertNotificationStmt.run(plant.id, message);
      }
    }
  }

  if (shouldRunDailyEvaluation(plant.illuminance_evaluated_at, now)) {
    const { avg_value: avgIlluminance, sample_count: sampleCount } =
      selectIlluminanceDaytimeAverageStmt.get(plant.id);

    if (avgIlluminance !== null && sampleCount > 0) {
      const status = classifyIlluminanceDailyAverage(avgIlluminance);
      updateIlluminanceDailyStmt.run(
        status,
        avgIlluminance,
        toSqliteTimestamp(now),
        plant.id,
      );

      if (status === 'needs_care') {
        const message = `過去24時間(昼間)の日照が不足しています(平均${avgIlluminance.toFixed(0)}lux)。日当たりの良い場所への移動を検討してください`;
        insertNotificationStmt.run(plant.id, message);
      }
    }
  }
}

// POST /sensor (設計書5-4)
//
// デバイスペアリング機能の実装に伴い、plant_idを直接受け取る簡易版から
// device_id起点の本来設計に戻した。ESP32はdevice_idを送り、サーバー側で
// plants.device_idを参照してどの植物のログかを判定する。
export function receiveSensorData(req, res) {
  const { device_id, temperature, humidity, soil, illuminance } =
    req.body ?? {};

  const validationError = validateSensorPayload({
    device_id,
    temperature,
    humidity,
    soil,
    illuminance,
  });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const plant = selectPlantByDeviceIdStmt.get(Number(device_id));
  if (!plant) {
    // デバイス自体は登録済みだが、どの植物にも紐付けられていない
    // (POST /plants または PATCH /plants/:id でdevice_idを設定していない)場合もここに来る。
    return sendError(
      res,
      404,
      'PLANT_NOT_FOUND',
      '指定されたデバイスに紐付く植物が見つかりません。先にPOST /plantsまたはPATCH /plants/:idでdevice_idを設定してください',
    );
  }

  insertLogStmt.run(
    plant.id,
    temperature ?? null,
    humidity ?? null,
    soil,
    illuminance ?? null,
  );

  const now = new Date();

  // 土壌水分: 受信のたびに閾値と比較して plants.status を更新する(設計書5-4・5-7)。
  // NOTE: plants.statusは現時点でも土壌水分専用のまま変更していない
  // (healthy/thirsty/dryという語彙自体が「水やり」を意味しており、
  // 温度・湿度・照度の悪化をここに混ぜるとホーム画面の元のメッセージ
  // (例:「乾燥しています」)と実態が食い違う可能性があるため。
  // 4項目のworst-ofをホーム画面にどう出すかはFlutter側の対応と合わせて
  // 別途検討する。docs/status-notification-design.md 3-5章を参照)。
  const previousSoilStatus = plant.status;
  const soilStatus = determineStatus(soil);
  updateStatusStmt.run(soilStatus, plant.id);
  maybeCreateSoilNotification(plant.id, previousSoilStatus, soilStatus);

  // 温度: リアルタイム・継続時間ベース(docs 3-1)。temperatureが未送信の場合はスキップ。
  if (temperature !== undefined && temperature !== null) {
    const previousTempStatus = plant.temp_status ?? 'healthy';
    const { status: tempStatus, since } = resolveTemperatureStatus(
      temperature,
      plant.temp_out_of_range_since,
      now,
    );
    updateTemperatureStmt.run(
      tempStatus,
      since ? toSqliteTimestamp(since) : null,
      plant.id,
    );
    maybeCreateTemperatureNotification(plant.id, previousTempStatus, tempStatus);
  }

  // 湿度・照度: 1日1回、15:00をまたいだ最初の受信で評価する(docs 5章・6-5章)。
  runDailyEvaluations(plant, now);

  res.status(201).json({ plant_id: plant.id, status: soilStatus });
}
