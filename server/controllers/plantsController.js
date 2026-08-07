import db from '../database/db.js';
import { sendError } from '../utils/errors.js';

const insertPlantStmt = db.prepare(
  `INSERT INTO plants (name, species, image, device_id) VALUES (?, ?, ?, ?)`,
);

const selectPlantStmt = db.prepare(`SELECT * FROM plants WHERE id = ?`);
const selectAllPlantsStmt = db.prepare(`SELECT * FROM plants ORDER BY id`);
const selectDeviceStmt = db.prepare(`SELECT * FROM devices WHERE id = ?`);

const updatePlantStmt = db.prepare(
  `UPDATE plants SET name = COALESCE(?, name), species = COALESCE(?, species), device_id = COALESCE(?, device_id) WHERE id = ?`,
);

const deletePlantStmt = db.prepare(`DELETE FROM plants WHERE id = ?`);

// created_at は datetime('now') で秒単位までしか記録されないため、
// 短時間に連続でデータが届くと created_at だけでは順序が確定しない。
// id は AUTOINCREMENT で必ず新しい行ほど大きくなるため、id DESC で確実に最新を取る。
const selectLatestLogStmt = db.prepare(
  `SELECT * FROM sensor_logs WHERE plant_id = ? ORDER BY id DESC LIMIT 1`,
);

/**
 * plants テーブルの1行と、直近の sensor_logs 1件を合成して
 * 設計書5-2のレスポンス例({ id, name, ..., temperature, ..., updated_at })
 * と同じ形にする。
 * まだセンサーデータが1件も届いていない植物は temperature 等が null になる。
 */
function toPlantResponse(plantRow) {
  const latestLog = selectLatestLogStmt.get(plantRow.id);
  return {
    id: plantRow.id,
    name: plantRow.name,
    species: plantRow.species,
    device_id: plantRow.device_id ?? null,
    status: plantRow.status,
    temperature: latestLog?.temperature ?? null,
    humidity: latestLog?.humidity ?? null,
    soil: latestLog?.soil ?? null,
    illuminance: latestLog?.illuminance ?? null,
    updated_at: latestLog?.created_at ?? null,
  };
}

// POST /plants (設計書5-2)
// device_idは任意項目(未接続でも登録可)。指定する場合は登録済みのデバイスである必要がある。
export function createPlant(req, res) {
  const { name, species, image, device_id } = req.body ?? {};

  if (!name || typeof name !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'name は必須です');
  }

  if (device_id !== undefined && device_id !== null) {
    const device = selectDeviceStmt.get(Number(device_id));
    if (!device) {
      return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
    }
  }

  const result = insertPlantStmt.run(
    name,
    species ?? null,
    image ?? null,
    device_id ?? null,
  );
  const created = selectPlantStmt.get(result.lastInsertRowid);

  res.status(201).json(toPlantResponse(created));
}

// GET /plants
export function listPlants(req, res) {
  const rows = selectAllPlantsStmt.all();
  res.json(rows.map(toPlantResponse));
}

// GET /plants/:id
export function getPlant(req, res) {
  const id = Number(req.params.id);
  const row = selectPlantStmt.get(id);

  if (!row) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  res.json(toPlantResponse(row));
}

// PATCH /plants/:id (設計書5-2)
// 編集可能なのは name / species / device_id。未指定のフィールドは現在の値を保持する。
// device_idはデバイスペアリング完了後にここで紐付ける想定(POST /devices/pairとは別操作)。
export function updatePlant(req, res) {
  const id = Number(req.params.id);
  const existing = selectPlantStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  const { name, species, device_id } = req.body ?? {};

  // JSONで明示的に`null`を送ってきた場合(未指定の意図)も「更新しない」扱いに
  // したいので、undefinedだけでなくnullも許容する(device_idの判定と揃える)。
  // これを`!== undefined`だけにしていると、クライアントが
  // {"name": null, "device_id": 1} のように一部フィールドだけ更新したい時に
  // 誤って400 VALIDATION_ERRORになってしまう(実際に発生した不具合)。
  if (name !== undefined && name !== null && (typeof name !== 'string' || name.trim() === '')) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'name は空でない文字列で指定してください');
  }
  if (species !== undefined && species !== null && typeof species !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'species は文字列で指定してください');
  }
  if (device_id !== undefined && device_id !== null) {
    const device = selectDeviceStmt.get(Number(device_id));
    if (!device) {
      return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
    }
  }

  updatePlantStmt.run(name ?? null, species ?? null, device_id ?? null, id);
  const updated = selectPlantStmt.get(id);
  res.json(toPlantResponse(updated));
}

// DELETE /plants/:id (設計書5-2)
// sensor_logsの外部キーにON DELETE CASCADEを設定しているため
// (database/db.js参照)、紐づくログも一緒に削除される。
export function deletePlant(req, res) {
  const id = Number(req.params.id);
  const existing = selectPlantStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  deletePlantStmt.run(id);
  res.status(204).end();
}
