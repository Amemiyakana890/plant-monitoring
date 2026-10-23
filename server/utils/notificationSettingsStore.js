import db from '../database/db.js';

const insertDefaultsStmt = db.prepare(
  `INSERT OR IGNORE INTO notification_settings (owner_uid) VALUES (?)`,
);
const selectByOwnerStmt = db.prepare(
  `SELECT * FROM notification_settings WHERE owner_uid = ?`,
);

export function getOrCreateNotificationSettings(ownerUid) {
  insertDefaultsStmt.run(ownerUid);
  return selectByOwnerStmt.get(ownerUid);
}
