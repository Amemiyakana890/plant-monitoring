import db from '../database/db.js';
import { determineStatus } from '../utils/plantStatus.js';
import { validateSensorPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';

const selectPlantStmt = db.prepare(`SELECT * FROM plants WHERE id = ?`);

const insertLogStmt = db.prepare(
  `INSERT INTO sensor_logs (plant_id, temperature, humidity, soil, illuminance)
   VALUES (?, ?, ?, ?, ?)`,
);

const updateStatusStmt = db.prepare(
  `UPDATE plants SET status = ? WHERE id = ?`,
);

const insertNotificationStmt = db.prepare(
  `INSERT INTO notifications (plant_id, message) VALUES (?, ?)`,
);

// 状態が「悪化した」場合にのみ通知するための順位付け(設計書5-7・F-05)。
// 「静かに見守る」コンセプト上、同じ状態が続く間は毎回通知しない。
const STATUS_RANK = { healthy: 0, thirsty: 1, dry: 2 };

const NOTIFICATION_MESSAGE = {
  thirsty: '少し乾いてきました。水やりのタイミングを確認してください',
  dry: '土壌水分が少なくなっています。水やりが必要です',
};

// 状態がpreviousStatusからnewStatusへ悪化した場合のみ通知を1件作成する。
// (healthy→thirsty、thirsty→dry、healthy→dryのいずれか。改善方向は通知しない)
function maybeCreateNotification(plantId, previousStatus, newStatus) {
  const previousRank = STATUS_RANK[previousStatus] ?? 0;
  const newRank = STATUS_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return;

  const message = NOTIFICATION_MESSAGE[newStatus];
  if (!message) return;

  insertNotificationStmt.run(plantId, message);
}

// POST /sensor
//
// 設計書5-4はESP32が device_id を送り、サーバーが devices.plant_id を
// 引く設計だったが、Arduino/M5 ATOM Matrix側の実装都合により、
// 今回は plant_id を直接受け取る簡易版にしている
// (デバイスのペアリング機能に着手する際に見直す想定。設計書5-4に注記済み)。
export function receiveSensorData(req, res) {
  const { plant_id, temperature, humidity, soil, illuminance } =
    req.body ?? {};

  const validationError = validateSensorPayload({
    plant_id,
    temperature,
    humidity,
    soil,
    illuminance,
  });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const plant = selectPlantStmt.get(Number(plant_id));
  if (!plant) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  insertLogStmt.run(
    plant.id,
    temperature ?? null,
    humidity ?? null,
    soil,
    illuminance ?? null,
  );

  // 受信のたびに閾値と比較して plants.status を更新する(設計書5-4・5-7)。
  const previousStatus = plant.status;
  const status = determineStatus(soil);
  updateStatusStmt.run(status, plant.id);
  maybeCreateNotification(plant.id, previousStatus, status);

  res.status(201).json({ plant_id: plant.id, status });
}
