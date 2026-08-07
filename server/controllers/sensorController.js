import db from '../database/db.js';
import { determineStatus } from '../utils/plantStatus.js';
import { validateSensorPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';

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

  // 受信のたびに閾値と比較して plants.status を更新する(設計書5-4・5-7)。
  const previousStatus = plant.status;
  const status = determineStatus(soil);
  updateStatusStmt.run(status, plant.id);
  maybeCreateNotification(plant.id, previousStatus, status);

  res.status(201).json({ plant_id: plant.id, status });
}
