import db from '../database/db.js';
import { sendError } from '../utils/errors.js';

const selectAllStmt = db.prepare(`
  SELECT n.* FROM notifications n
  JOIN plants p ON p.id = n.plant_id
  WHERE p.owner_uid = ?
  ORDER BY n.id DESC
`);
const selectByIdStmt = db.prepare(`
  SELECT n.* FROM notifications n
  JOIN plants p ON p.id = n.plant_id
  WHERE n.id = ? AND p.owner_uid = ?
`);
const updateReadStmt = db.prepare(`
  UPDATE notifications
  SET is_read = 1
  WHERE id = ? AND plant_id IN (
    SELECT id FROM plants WHERE owner_uid = ?
  )
`);

// GET /notifications (設計書5-6)
export function listNotifications(req, res) {
  res.json(selectAllStmt.all(req.user.uid));
}

// PATCH /notifications/:id (設計書5-6)
// 現状 is_read: true への変更のみ受け付ける(未読へ戻す操作は要件に無いため)。
export function markNotificationRead(req, res) {
  const id = Number(req.params.id);
  const existing = selectByIdStmt.get(id, req.user.uid);

  if (!existing) {
    return sendError(res, 404, 'NOTIFICATION_NOT_FOUND', '指定された通知が見つかりません');
  }

  const { is_read } = req.body ?? {};
  if (is_read !== true) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'is_read は true のみ指定できます');
  }

  updateReadStmt.run(id, req.user.uid);
  res.json(selectByIdStmt.get(id, req.user.uid));
}
