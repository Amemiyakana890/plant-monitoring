import db from '../database/db.js';
import { validateDevicePairPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';

const insertDeviceStmt = db.prepare(
  `INSERT INTO devices (device_name, mac_address) VALUES (?, ?)`,
);

const selectDeviceStmt = db.prepare(`SELECT * FROM devices WHERE id = ?`);
const selectDeviceByMacStmt = db.prepare(
  `SELECT * FROM devices WHERE mac_address = ?`,
);
const selectAllDevicesStmt = db.prepare(`SELECT * FROM devices ORDER BY id`);

// 同じMACアドレスのデバイスが再接続してきた場合に使う「再アクティブ化」用。
// 行を作り直す(削除→INSERT)とAUTOINCREMENTでidが進んでしまい、実機
// (ESP32)側のDEVICE_ID定数を都度書き換える必要が生じていたため、
// 既存の行を使い回してidを不変に保つ(2026-08-07の変更。
// device-test-log01.md参照)。
const reactivateDeviceStmt = db.prepare(
  `UPDATE devices SET device_name = ?, status = 'connected', paired_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?`,
);

// ペアリング解除(unpairDevice)用。デバイス行自体は削除せず、
// 「この植物との紐付けを外す」+「未接続状態にする」だけを行う。
const unlinkPlantsByDeviceIdStmt = db.prepare(
  `UPDATE plants SET device_id = NULL WHERE device_id = ?`,
);
const updateDeviceStatusStmt = db.prepare(
  `UPDATE devices SET status = ? WHERE id = ?`,
);

function toDeviceResponse(row) {
  return {
    id: row.id,
    device_name: row.device_name,
    mac_address: row.mac_address,
    firmware_version: row.firmware_version,
    battery_level: row.battery_level,
    status: row.status,
    paired_at: row.paired_at,
  };
}

// GET /devices (設計書5-1・5-3)
export function listDevices(req, res) {
  const rows = selectAllDevicesStmt.all();
  res.json(rows.map(toDeviceResponse));
}

// GET /devices/:id (設計書5-3)
export function getDevice(req, res) {
  const id = Number(req.params.id);
  const row = selectDeviceStmt.get(id);

  if (!row) {
    return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
  }

  res.json(toDeviceResponse(row));
}

// POST /devices/pair (設計書5-3)
//
// アプリがBluetooth/Wi-Fi経由でデバイスを検出した後、サーバーに
// ペアリング情報を登録するためのエンドポイント(現状の検出手段自体は
// 未実装で、デバイス名・MACアドレスの登録だけを担う。README進捗の
// 「デバイスペアリング機能の実装」のうちAPI/DB部分に対応)。
//
// 同じmac_addressのデバイスが既に存在する場合はエラーにせず、
// 実機の再接続(電源off/on、Wi-Fi再接続等)とみなして既存の行を
// 再アクティブ化する(2026-08-07変更。以前は409 DEVICE_ALREADY_PAIREDを
// 返していたが、実機の運用上「同じ機体の再接続」は正常系のため、
// 都度エラーにするのは実態に合っていなかった)。
export function pairDevice(req, res) {
  const { device_name, mac_address } = req.body ?? {};

  const validationError = validateDevicePairPayload({ device_name, mac_address });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const existing = selectDeviceByMacStmt.get(mac_address);
  if (existing) {
    reactivateDeviceStmt.run(device_name, existing.id);
    const reactivated = selectDeviceStmt.get(existing.id);
    return res.status(200).json(toDeviceResponse(reactivated));
  }

  const result = insertDeviceStmt.run(device_name, mac_address);
  const created = selectDeviceStmt.get(result.lastInsertRowid);

  res.status(201).json(toDeviceResponse(created));
}

// DELETE /devices/:id (設計書5-1「デバイスのペアリング解除」)
//
// 2026-08-07変更: 以前はデバイス行そのものを削除していたが、それだと
// 同じ実機で再ペアリングした際に新しい連番idが振られてしまい、
// ESP32側のDEVICE_ID定数をそのたびに書き換える必要があった。
// 今は行を削除せず、(1)紐付いていた植物のdevice_idをNULLに戻す、
// (2)デバイスのstatusをdisconnectedにする、の2つだけを行う。
// 同じmac_addressで再度POST /devices/pairすれば、同じidのまま
// 再アクティブ化される(pairDevice参照)。
export function unpairDevice(req, res) {
  const id = Number(req.params.id);
  const existing = selectDeviceStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
  }

  unlinkPlantsByDeviceIdStmt.run(id);
  updateDeviceStatusStmt.run('disconnected', id);

  res.status(204).end();
}
