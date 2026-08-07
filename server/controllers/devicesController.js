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
const deleteDeviceStmt = db.prepare(`DELETE FROM devices WHERE id = ?`);

// plants.device_idはON DELETE SET NULLのため、DELETE /devices/:idを実行しても
// 植物自体は消えず「デバイス未接続」の状態に戻るだけになる(設計書6章参照)。

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
export function pairDevice(req, res) {
  const { device_name, mac_address } = req.body ?? {};

  const validationError = validateDevicePairPayload({ device_name, mac_address });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const existing = selectDeviceByMacStmt.get(mac_address);
  if (existing) {
    return sendError(
      res,
      409,
      'DEVICE_ALREADY_PAIRED',
      'このデバイスは既にペアリング済みです',
    );
  }

  const result = insertDeviceStmt.run(device_name, mac_address);
  const created = selectDeviceStmt.get(result.lastInsertRowid);

  res.status(201).json(toDeviceResponse(created));
}

// DELETE /devices/:id (設計書5-1「デバイスのペアリング解除」)
export function unpairDevice(req, res) {
  const id = Number(req.params.id);
  const existing = selectDeviceStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
  }

  deleteDeviceStmt.run(id);
  res.status(204).end();
}
