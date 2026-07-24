import { DatabaseSync } from 'node:sqlite';

// node:sqliteについて:
// Node.js組み込みのため依存パッケージを増やさずに済むが、2026年7月時点でも
// 起動時に ExperimentalWarning が出る実験的機能であり、将来APIが変わる
// 可能性がある(参考: 展示・卒制用途では許容範囲という判断で採用している)。
// もし本番運用まで見据える場合は better-sqlite3 等への切り替えも検討する。
//
// 今回は「核となる部分」のみのため、plants と sensor_logs だけ作成する。
// devices / notifications / notification_settings は、デバイス接続機能や
// 通知機能に着手するタイミングで追加する(設計書6章のER図を参照)。
const db = new DatabaseSync('plant_monitoring.db');

// SQLiteは PRAGMA foreign_keys = ON を明示しない限り外部キー制約を
// 強制しない(デフォルトはOFF)。存在しないplant_idのログが紛れ込んだり、
// 参照されているplantsの行が誤って残ったりする事故を防ぐため有効化する。
db.exec('PRAGMA foreign_keys = ON;');

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
    plant_id INTEGER NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    temperature REAL,
    humidity REAL,
    soil REAL,
    illuminance REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

export default db;
