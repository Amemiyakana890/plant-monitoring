import db from '../database/db.js';
import { validateDeviceTokenPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';

// Push通知(FCM)用のデバイストークン管理(docs/push-notification-design.md 4章)。
//
// 注意: `devices`テーブル(ESP32センサーデバイスのペアリング情報、
// devicesController.js参照)とは全く別物。こちらは「ユーザーのスマートフォン」
// 側のFCMトークンを保存する device_tokens テーブル(database/db.js参照)を扱う。
// URLが/devices/tokensと紛らわしいが、設計ドキュメントの命名をそのまま踏襲している。

const upsertDeviceTokenStmt = db.prepare(`
  INSERT INTO device_tokens (owner_uid, fcm_token, platform, updated_at)
  VALUES (?, ?, ?, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  ON CONFLICT(fcm_token) DO UPDATE SET
    owner_uid = excluded.owner_uid,
    platform = excluded.platform,
    updated_at = excluded.updated_at
`);

const deleteDeviceTokenStmt = db.prepare(
  `DELETE FROM device_tokens WHERE fcm_token = ? AND owner_uid = ?`,
);

// PUT /devices/tokens (要ログイン、docs 4-1章)
//
// fcm_tokenをキーにUPSERTする。既に別のuidで登録されていた場合も、
// 今回リクエストしたuid(=ログイン中のFirebaseトークンから取得。requireAuthが
// req.userにセットする)で上書きする。これは「同一端末でユーザーが切り替わった
// 場合、最新のログインuidで上書きする」という2026年8月の決定に基づく
// (docs 3章・9-1章参照。誤送信防止のため)。
//
// アプリはログイン成功時・FCMトークンのonTokenRefresh発火時の両方でこのAPIを
// 呼ぶ想定(docs 6-2章)。
export function registerDeviceToken(req, res) {
  const { fcm_token, platform } = req.body ?? {};

  const validationError = validateDeviceTokenPayload({ fcm_token, platform });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const uid = req.user.uid;
  upsertDeviceTokenStmt.run(uid, fcm_token, platform ?? 'android');

  res.status(200).json({ fcm_token, platform: platform ?? 'android' });
}

// DELETE /devices/tokens (要ログイン、docs 4-2章)
//
// ログアウト時に呼ぶ想定(任意。v1のスコープでは必須ではない)。
// 自分(ログイン中のuid)が登録したトークンのみ削除できるよう、
// WHERE句にowner_uidも含めている(他ユーザーのトークンを誤って
// 消せないようにするため)。
export function deleteDeviceToken(req, res) {
  const { fcm_token } = req.body ?? {};

  if (typeof fcm_token !== 'string' || fcm_token.trim() === '') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'fcm_token は空でない文字列で指定してください');
  }

  const uid = req.user.uid;
  deleteDeviceTokenStmt.run(fcm_token, uid);

  res.status(204).end();
}
