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

// 水やり記録(docs/status-notification-design.md 4-2章)。
// センサーだけでは「水やりした瞬間」が分からないため、ホーム画面の
// 「水やりした」ボタン(土壌水分カード内)から明示的に記録できるようにする。
// v1では「最後にいつ水をあげたか」が分かれば十分なため、履歴の一覧・
// グラフへの反映(3-3章で触れた「水やりタイミングをマーカー表示」)は
// 保留し、まずは記録・直近日時の表示のみ対応する。
db.exec(`
  CREATE TABLE IF NOT EXISTS watering_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    watered_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

// 通知/アラート画面(設計書5-6・F-05/F-06)向け。
// notification_settingsテーブル自体は本ファイル下部(サイレントタイム関連の
// マイグレーション)で追加している。devicesは上で追加済み。
db.exec(`
  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
`);

// マイグレーション: 通知のカテゴリ(docs/status-notification-design.md関連)。
// 'soil' / 'temperature' / 'humidity' / 'illuminance' のいずれかを想定。
// もともとFlutter側(notification_page.dart)は通知メッセージの文言に
// 「水分」「湿度」等のキーワードが含まれるかどうかでアイコンを推測していたが、
// 土壌水分の「やや乾燥」メッセージ(「少し乾いてきました。水やりのタイミングを
// 確認してください」)には「水分」という文字列が含まれておらず、汎用アイコン
// (ベルのみ)になってしまうバグがあった。文言に依存しない判定にするため、
// サーバー側で明示的なカテゴリを持たせることにした。
// 移行前に作成された既存の通知行はcategoryがNULLのままになるため、
// Flutter側は「categoryがあれば優先、無ければ従来のキーワード判定にフォール
// バックする」という互換動作にしている(models/plant_notification.dart参照)。
const notificationsColumns = db.prepare('PRAGMA table_info(notifications)').all();
const hasCategoryColumn = notificationsColumns.some((col) => col.name === 'category');
if (!hasCategoryColumn) {
  db.exec('ALTER TABLE notifications ADD COLUMN category TEXT;');
}

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

// マイグレーション: 温度・湿度・照度の状態判定・通知ロジック用カラム
// (docs/status-notification-design.md 4章)。
// temp_status / temp_out_of_range_since : 温度はリアルタイム評価(3-1章)。
//   caution_zone(適正範囲の外)に入り続けている開始時刻をtemp_out_of_range_sinceに
//   記録し、経過時間からtemp_statusを算出する(utils/plantStatus.js参照)。
// humidity_daily_* / illuminance_daily_* : 湿度・照度は1日1回・15:00に評価する
//   「日次レポート型」(3-2, 3-4章)。評価結果と評価時刻を保存しておき、
//   次にPOST /sensorを受信した際に「今日はまだ評価していないか」を判定する。
const newPlantColumns = [
  { name: 'temp_status', ddl: "temp_status TEXT NOT NULL DEFAULT 'healthy'" },
  { name: 'temp_out_of_range_since', ddl: 'temp_out_of_range_since TEXT' },
  { name: 'humidity_daily_status', ddl: 'humidity_daily_status TEXT' },
  { name: 'humidity_daily_avg', ddl: 'humidity_daily_avg REAL' },
  { name: 'humidity_evaluated_at', ddl: 'humidity_evaluated_at TEXT' },
  { name: 'illuminance_daily_status', ddl: 'illuminance_daily_status TEXT' },
  { name: 'illuminance_daily_avg', ddl: 'illuminance_daily_avg REAL' },
  { name: 'illuminance_evaluated_at', ddl: 'illuminance_evaluated_at TEXT' },
];
const currentPlantColumns = db.prepare('PRAGMA table_info(plants)').all();
for (const column of newPlantColumns) {
  const exists = currentPlantColumns.some((col) => col.name === column.name);
  if (!exists) {
    db.exec(`ALTER TABLE plants ADD COLUMN ${column.ddl};`);
  }
}

// マイグレーション: 土壌水分の季節別閾値・継続時間判定(docs 3-3章)用カラム。
// temp_out_of_range_sinceと同じ役割で、caution_zone(注意ゾーン)に入り続けている
// 開始時刻を保持する(utils/plantStatus.jsのresolveSoilStatus参照)。
// 要ケアゾーンは継続時間を問わない(水やり緩和のみ)ため専用カラムは不要。
const soilStatusColumns = [
  { name: 'soil_caution_since', ddl: 'soil_caution_since TEXT' },
];
const plantColumnsForSoil = db.prepare('PRAGMA table_info(plants)').all();
for (const column of soilStatusColumns) {
  const exists = plantColumnsForSoil.some((col) => col.name === column.name);
  if (!exists) {
    db.exec(`ALTER TABLE plants ADD COLUMN ${column.ddl};`);
  }
}

// マイグレーション: サイレントタイム(docs/status-notification-design.md 6-4章)。
// 通知設定はアプリ全体で1レコードのみ保持する(設計書6章ER図の注記通り)。
// id=1固定で1行だけ運用し、初回起動時にデフォルト値(20:00〜06:00)を投入する。
db.exec(`
  CREATE TABLE IF NOT EXISTS notification_settings (
    id INTEGER PRIMARY KEY,
    frequency TEXT NOT NULL DEFAULT 'necessary_only',
    start_time TEXT NOT NULL DEFAULT '20:00',
    end_time TEXT NOT NULL DEFAULT '06:00',
    sound_enabled INTEGER NOT NULL DEFAULT 1
  );
`);
db.exec(`
  INSERT OR IGNORE INTO notification_settings (id, frequency, start_time, end_time, sound_enabled)
  VALUES (1, 'necessary_only', '20:00', '06:00', 1);
`);

// plants.pending_notification : サイレントタイム中に「悪化」が起きたかどうかの
//   フラグ(0/1)。悪化のたびに1に立てるだけで、通知の中身はここでは保持しない
//   (解禁時にその時点の最新の状態から作り直すため。docs 6-4章)。
//   すべての項目が適正に戻った場合は0にクリアする。
// plants.silent_time_unlock_checked_at : 直近でサイレントタイム解禁チェックを
//   行った時刻。1日1回だけ解禁通知を行うためのマーカー(5章の日次評価と同じ
//   設計パターン。utils/time.jsのhasPassedDailyMarkerを参照)。
const silentTimePlantColumns = [
  { name: 'pending_notification', ddl: 'pending_notification INTEGER NOT NULL DEFAULT 0' },
  { name: 'silent_time_unlock_checked_at', ddl: 'silent_time_unlock_checked_at TEXT' },
];
const plantColumnsAfterDaily = db.prepare('PRAGMA table_info(plants)').all();
for (const column of silentTimePlantColumns) {
  const exists = plantColumnsAfterDaily.some((col) => col.name === column.name);
  if (!exists) {
    db.exec(`ALTER TABLE plants ADD COLUMN ${column.ddl};`);
  }
}

// マイグレーション: 通知アラートのカテゴリ別ON/OFF。
// トグルOFFは「通知の生成だけを止める」設計とし、判定ロジックやホーム画面の
// バッジ表示(status/temp_status/humidity_daily_status/illuminance_daily_status)
// には一切影響しない(サイレントタイムと同じ「見守り自体は止めない」考え方)。
// バッテリーアラートは、そもそもバッテリー残量を送信する仕組み自体が
// ESP32側に無く実用化はまだ先のため、今回はスコープ外(列を追加しない)。
const notificationToggleColumns = [
  { name: 'soil_alert_enabled', ddl: 'soil_alert_enabled INTEGER NOT NULL DEFAULT 1' },
  { name: 'temperature_alert_enabled', ddl: 'temperature_alert_enabled INTEGER NOT NULL DEFAULT 1' },
  { name: 'humidity_alert_enabled', ddl: 'humidity_alert_enabled INTEGER NOT NULL DEFAULT 1' },
  { name: 'illuminance_alert_enabled', ddl: 'illuminance_alert_enabled INTEGER NOT NULL DEFAULT 1' },
];
const notificationSettingsColumns = db.prepare('PRAGMA table_info(notification_settings)').all();
for (const column of notificationToggleColumns) {
  const exists = notificationSettingsColumns.some((col) => col.name === column.name);
  if (!exists) {
    db.exec(`ALTER TABLE notification_settings ADD COLUMN ${column.ddl};`);
  }
}

export default db;
