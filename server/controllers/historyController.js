import db from '../database/db.js';
import { sendError } from '../utils/errors.js';

// 設計書5-5: range は 24h / 7d / 30d のいずれか(デフォルト7d)。
// SQLiteのdatetime('now', ?)にそのまま渡せる修飾子にマッピングしておく。
const RANGE_TO_MODIFIER = {
  '24h': '-24 hours',
  '7d': '-7 days',
  '30d': '-30 days',
};

const selectPlantStmt = db.prepare(`SELECT id FROM plants WHERE id = ?`);

// range値ごとにprepareし直すコストを避けるため、あらかじめ3種類だけ用意しておく。
const selectLogsStmtByRange = Object.fromEntries(
  Object.keys(RANGE_TO_MODIFIER).map((range) => [
    range,
    db.prepare(
      `SELECT temperature, humidity, soil, illuminance, created_at
       FROM sensor_logs
       WHERE plant_id = ? AND created_at >= datetime('now', ?)
       ORDER BY created_at ASC`,
    ),
  ]),
);

// GET /history/:plantId?range=24h|7d|30d (設計書5-5)
export function getHistory(req, res) {
  const plantId = Number(req.params.plantId);
  const plant = selectPlantStmt.get(plantId);
  if (!plant) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  const range = typeof req.query.range === 'string' ? req.query.range : '7d';
  const stmt = selectLogsStmtByRange[range];
  if (!stmt) {
    return sendError(
      res,
      400,
      'VALIDATION_ERROR',
      'range は 24h / 7d / 30d のいずれかで指定してください',
    );
  }

  // 注: from/to(ISO8601)による直接指定は設計書5-5に記載があるが、
  // 現段階ではrangeベースのみ実装している。必要になり次第対応する。
  const logs = stmt.all(plantId, RANGE_TO_MODIFIER[range]);

  res.json({ plant_id: plantId, range, logs });
}
