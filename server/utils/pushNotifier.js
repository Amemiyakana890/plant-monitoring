import { getMessaging } from 'firebase-admin/messaging';
import db from '../database/db.js';

// Push通知(FCM)の送信本体(docs/push-notification-design.md 5章)。
//
// getMessaging()は引数なしで呼ぶと、app.js側で先に初期化済みのデフォルトの
// Firebaseアプリ(firebase_admin.js参照)をそのまま使う(require_auth.jsの
// getAuth()と同じパターン)。そのため、このファイル単体でFirebaseの
// 初期化をやり直す必要はない。

const selectAllTokensStmt = db.prepare(
  `SELECT fcm_token FROM device_tokens WHERE owner_uid = ?`,
);
const deleteTokenStmt = db.prepare(
  `DELETE FROM device_tokens WHERE fcm_token = ? AND owner_uid = ?`,
);

// 呼び出し元(sensorController.jsのcreateNotification())が例外を
// try/catchで隔離するため、ここでは特にcatchせず素直にthrowしてよい。
export async function sendPushNotification(message, ownerUid) {
  const tokens = selectAllTokensStmt.all(ownerUid).map((row) => row.fcm_token);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: '植物見守り', body: message },
  });

  // 無効化されたトークン(アンインストール・期限切れ等)はDBから削除しておく
  // (docs 5-2章)。次回以降、無駄な送信・エラーログを減らすため。
  response.responses.forEach((result, i) => {
    if (
      !result.success &&
      result.error?.code === 'messaging/registration-token-not-registered'
    ) {
      deleteTokenStmt.run(tokens[i], ownerUid);
    }
  });
}
