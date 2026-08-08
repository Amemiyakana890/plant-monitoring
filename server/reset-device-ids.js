// 一回限りの手動クリーンアップ用スクリプト。
//
// 開発中に何度もペアリングを試した結果、devicesテーブルに使われていない
// 古い行(id=1, 2など)が残り、実際に使っているデバイスのidが3のように
// 大きい番号になってしまった状態を整理する。
//
// やること:
//   1. 現在いずれかの植物に紐付いているデバイス(1台だけの想定)を探す
//   2. それ以外のデバイス行を削除する
//   3. 残したデバイスのidを1に振り直す(参照しているplants.device_idも更新)
//   4. AUTOINCREMENTの採番をリセットする(次に新規追加する行がid=2から始まるように)
//
// 使い方:
//   1. サーバー(node app.js)を一旦止める
//   2. server/ ディレクトリで `node reset-device-ids.js` を実行
//   3. 実行結果を確認してから、サーバーを再度起動する
//   4. ESP32側の DEVICE_ID を 1 に書き換えて再書き込みする

import { DatabaseSync } from 'node:sqlite';
import './env.js';

const db = new DatabaseSync(process.env.DB_PATH ?? 'plant_monitoring.db');

const plantsWithDevice = db
  .prepare(`SELECT id, name, device_id FROM plants WHERE device_id IS NOT NULL`)
  .all();

if (plantsWithDevice.length === 0) {
  console.log('現在デバイスに紐付いている植物がありません。何もせず終了します。');
  console.log('(先にアプリでペアリング・紐付けを行ってから実行してください)');
  process.exit(0);
}

if (plantsWithDevice.length > 1) {
  console.log('複数の植物にデバイスが紐付いています(v1では1台構成のはずです):');
  console.table(plantsWithDevice);
  console.log('想定外の状態のため、安全のため自動処理を中止します。手動で確認してください。');
  process.exit(1);
}

const targetDeviceId = plantsWithDevice[0].device_id;

if (targetDeviceId === 1) {
  console.log('既にdevice_idは1です。何もする必要はありません。');
  process.exit(0);
}

console.log(`現在紐付いているデバイスid: ${targetDeviceId} → 1 に振り直します。`);

const allDevicesBefore = db.prepare(`SELECT * FROM devices ORDER BY id`).all();
console.log('--- 変更前のdevicesテーブル ---');
console.table(allDevicesBefore);

// このブロックの中では「devicesのid変更」と「plants.device_idの更新」を
// 2つの別々の文で行うため、一瞬だけ整合性が崩れた中間状態を通る
// (例: idを1に変える瞬間、まだplants側は3を参照したまま)。
// PRAGMA foreign_keys = ONのままだとこの中間状態でエラーになってしまうため、
// 一時的にオフにする(最終的な状態は必ず整合するため安全)。
//
// 注意: SQLiteの仕様上、PRAGMA foreign_keysは「トランザクションの外側」でしか
// 変更できない(BEGIN〜COMMITの中で実行しても無視される)。そのため
// BEGIN TRANSACTIONより前で切り替える必要がある。
db.exec('PRAGMA foreign_keys = OFF');
db.exec('BEGIN TRANSACTION');
try {
  // 使われていない他のデバイス行を削除
  db.prepare(`DELETE FROM devices WHERE id != ?`).run(targetDeviceId);

  // 対象デバイスのidを1に振り直す
  db.prepare(`UPDATE devices SET id = 1 WHERE id = ?`).run(targetDeviceId);

  // 参照している植物側も更新
  db.prepare(`UPDATE plants SET device_id = 1 WHERE device_id = ?`).run(targetDeviceId);

  // AUTOINCREMENTの採番をリセット(次のINSERTがid=2から始まるようにする)
  db.prepare(`DELETE FROM sqlite_sequence WHERE name = 'devices'`).run();
  db.prepare(`INSERT INTO sqlite_sequence (name, seq) VALUES ('devices', 1)`).run();

  db.exec('COMMIT');
} catch (err) {
  db.exec('ROLLBACK');
  console.error('エラーが発生したため変更をロールバックしました:', err);
  process.exit(1);
} finally {
  // トランザクション終了後(COMMIT/ROLLBACK後)なら変更できる。
  db.exec('PRAGMA foreign_keys = ON');
}

console.log('--- 変更後のdevicesテーブル ---');
console.table(db.prepare(`SELECT * FROM devices ORDER BY id`).all());

console.log('--- 変更後のplantsテーブル(device_id列のみ) ---');
console.table(db.prepare(`SELECT id, name, device_id FROM plants ORDER BY id`).all());

console.log('');
console.log('完了しました。ESP32側の DEVICE_ID を 1 に書き換えて再書き込みしてください。');
