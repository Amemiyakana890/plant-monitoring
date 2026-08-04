import { DatabaseSync } from 'node:sqlite';

// node:sqliteについて:
// Node.js組み込みのため依存パッケージを増やさずに済むが、2026年7月時点でも
// 起動時に ExperimentalWarning が出る実験的機能であり、将来APIが変わる
// 可能性がある(参考: 展示・卒制用途では許容範囲という判断で採用している)。
// もし本番運用まで見据える場合は better-sqlite3 等への切り替えも検討する。
const db = new DatabaseSync('plant_monitoring.db');

// SQLiteは PRAGMA foreign_keys = ON を明示しない限り外部キー制約を
// 強制しない(デフォルトはOFF)。存在しないplant_idのログが紛れ込んだり、
// 参照されているplantsの行が誤って残ったりする事故を防ぐため有効化する。
db.exec('PRAGMA foreign_keys = ON;');

// created_atはUTCで保存し、末尾にZを付与してタイムゾーンを明示する
// (例: "2026-08-04T01:08:52Z")。以前は datetime('now') を使っており、
// タイムゾーン情報のない "2026-08-04 01:08:52" 形式だったため、
// Flutter側でローカル時刻として誤解釈され表示が9時間ズレる原因になっていた。
// 表示側(Plant.updatedAtDisplay)で .toLocal() する前提のフォーマット。
db.exec(`
  CREATE TABLE IF NOT EXISTS plants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    species TEXT,
    image TEXT,
    status TEXT NOT NULL DEFAULT 'healthy',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
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
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

// 通知/アラート画面(設計書5-6・F-05/F-06)向け。
// devices / notification_settings はデバイス接続機能・通知設定画面に
// 着手するタイミングで追加する(設計書6章のER図を参照)。
db.exec(`
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

export default db;
