import db from '../database/db.js';
import { sendError } from '../utils/errors.js';

const insertPlantStmt = db.prepare(
  `INSERT INTO plants (name, species, image) VALUES (?, ?, ?)`,
);

const selectPlantStmt = db.prepare(`SELECT * FROM plants WHERE id = ?`);
const selectAllPlantsStmt = db.prepare(`SELECT * FROM plants ORDER BY id`);

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
    status: plantRow.status,
    temperature: latestLog?.temperature ?? null,
    humidity: latestLog?.humidity ?? null,
    soil: latestLog?.soil ?? null,
    illuminance: latestLog?.illuminance ?? null,
    updated_at: latestLog?.created_at ?? null,
  };
}

// POST /plants (設計書5-2)
// 現段階ではデバイスのペアリング機能は未実装のため、device_id は受け取らない。
// デバイス接続機能に着手するタイミングで追加する想定。
export function createPlant(req, res) {
  const { name, species, image } = req.body ?? {};

  if (!name || typeof name !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'name は必須です');
  }

  const result = insertPlantStmt.run(name, species ?? null, image ?? null);
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
