/**
 * database/db.jsのcreated_at等と同じ形式("2026-08-04T01:08:52Z", UTC・秒精度)に
 * Dateを変換する。JSのDate#toISOString()はミリ秒まで含む
 * ("...123Z")ため、そのまま保存するとDB側の文字列フォーマットとズレる。
 */
export function toSqliteTimestamp(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/**
 * 湿度・照度の「日次レポート」(docs/status-notification-design.md 5章)を
 * 今回のPOST /sensor受信時に評価すべきかどうかを判定する。
 *
 * ルール:「本日の15:00をまたいで、最初にセンサーを受信したタイミングで評価する」
 * (サイレントタイムの解禁判定と同じ、スケジューラを持たない設計パターン)。
 *
 * @param {string|null} evaluatedAt 前回評価した時刻(ISO8601、DB保存値)。未評価ならnull。
 * @param {Date} now 現在時刻(テスト容易性のため引数で渡せるようにしている)
 * @returns {boolean} 今回評価を実行すべきならtrue
 */
export function shouldRunDailyEvaluation(evaluatedAt, now = new Date()) {
  const todayAt15 = new Date(now);
  todayAt15.setHours(15, 0, 0, 0);

  // まだ本日の15:00に達していない → 前日分の評価をそのまま維持する。
  if (now.getTime() < todayAt15.getTime()) return false;

  // 一度も評価したことがない(セットアップ直後など) → 実行する。
  if (!evaluatedAt) return true;

  // 前回評価が「本日の15:00より前」なら、今日分がまだ未実施ということ。
  return new Date(evaluatedAt).getTime() < todayAt15.getTime();
}
