import { DatabaseSync } from 'node:sqlite';

// node:sqliteについて:
// Node.js組み込みのため依存パッケージを増やさずに済むが、2026年7月時点でも
// 起動時に ExperimentalWarning が出る実験的機能であり、将来APIが変わる
// 可能性がある(参考: 展示・卒制用途では許容範囲という判断で採用している)。
// もし本番運用まで見据える場合は better-sqlite3 等への切り替えも検討する。
// DB_PATHは.env(env.js経由)から読み込む。app.jsの一番最初で
// `import './env.js'` されている前提(このファイルはplants.js経由で
// app.jsから間接的にimportされるため、env.jsの評価が先に終わっている)。
// 未設定時は従来どおり'plant_monitoring.db'(server/直下)を使う。
const db = new DatabaseSync(process.env.DB_PATH ?? 'plant_monitoring.db');

// SQLiteは PRAGMA foreign_keys = ON を明示しない限り外部キー制約を
// 強制しない(デフォルトはOFF)。存在しないplant_idのログが紛れ込んだり、
// 参照されているplantsの行が誤って残ったりする事故を防ぐため有効化する。
db.exec('PRAGMA foreign_keys = ON;');

// created_atはUTCで保存し、末尾にZを付与してタイムゾーンを明示する
// (例: "2026-08-04T01:08:52Z")。以前は datetime('now') を使っており、
// タイムゾーン情報のない "2026-08-04 01:08:52" 形式だったため、
// Flutter側でローカル時刻として誤解釈され表示が9時間ズレる原因になっていた。
// 表示側(Plant.updatedAtDisplay)で .toLocal() する前提のフォーマット。
// devicesはplantsより先に作成する(plants.device_idがdevicesを参照するため)。
db.exec(`
  CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_name TEXT NOT NULL,
    mac_address TEXT NOT NULL UNIQUE,
    firmware_version TEXT,
    battery_level INTEGER,
    status TEXT NOT NULL DEFAULT 'connected',
    paired_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

// device_idは「未接続でも登録可」(設計書6章plantsテーブル定義)のためNULL許容。
// 2026-08-07以降、DELETE /devices/:id(ペアリング解除)はデバイス行自体を
// 削除しなくなった(plants.device_idをNULLに戻すだけ。devicesController.js
// 参照)ため、このON DELETE SET NULLは通常のAPI経由では発火しなくなった。
// ただし将来デバイス行を直接削除する機能を作った場合の保険として残している。
db.exec(`
  CREATE TABLE IF NOT EXISTS plants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER REFERENCES devices(id) ON DELETE SET NULL,
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
// notification_settingsは通知設定画面に着手するタイミングで追加する
// (設計書6章のER図を参照)。devicesは上で追加済み。
db.exec(`
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

// マイグレーション: 既存のplant_monitoring.dbは`CREATE TABLE IF NOT EXISTS`実行時点で
// 既にplantsテーブルが存在する(=device_id列を持たない状態)ため、上のCREATE TABLE文
// だけでは列が追加されない。PRAGMA table_infoで存在確認し、無ければ追加する。
const plantColumns = db.prepare('PRAGMA table_info(plants)').all();
const hasDeviceIdColumn = plantColumns.some((col) => col.name === 'device_id');
if (!hasDeviceIdColumn) {
  // SQLiteのALTER TABLE ADD COLUMNはREFERENCES制約を書けても外部キー制約自体は
  // 有効にならない場合があるため、あくまで参照用の列として追加する
  // (PRAGMA foreign_keys = ONは新規のINSERT/UPDATE時のFK違反チェックには効くが、
  // 既存テーブルへの列追加時の制約定義には影響しない点に注意)。
  db.exec('ALTER TABLE plants ADD COLUMN device_id INTEGER REFERENCES devices(id) ON DELETE SET NULL;');
}

export default db;
