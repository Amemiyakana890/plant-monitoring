import { DatabaseSync } from 'node:sqlite';

// 今回は「核となる部分」のみのため、plants と sensor_logs だけ作成する。
// devices / notifications / notification_settings は、デバイス接続機能や
// 通知機能に着手するタイミングで追加する(設計書6章のER図を参照)。
const db = new DatabaseSync('plant_monitoring.db');

db.exec(`
  CREATE TABLE IF NOT EXISTS plants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    species TEXT,
    image TEXT,
    status TEXT NOT NULL DEFAULT 'healthy',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS sensor_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL REFERENCES plants(id),
    temperature REAL,
    humidity REAL,
    soil REAL,
    illuminance REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

export default db;
