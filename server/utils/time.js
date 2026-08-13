/**
 * database/db.jsのcreated_at等と同じ形式("2026-08-04T01:08:52Z", UTC・秒精度)に
 * Dateを変換する。JSのDate#toISOString()はミリ秒まで含む
 * ("...123Z")ため、そのまま保存するとDB側の文字列フォーマットとズレる。
 */
export function toSqliteTimestamp(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/**
 * "HH:MM"形式の文字列を{ hour, minute }に変換する。
 * 不正な形式の場合はnullを返す(呼び出し側でデフォルト値にフォールバックする)。
 */
export function parseHourMinute(value) {
  if (typeof value !== 'string') return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;

  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return { hour, minute };
}

/**
 * 「1日1回、決まった時刻(hour:minute)をまたいだタイミングで何かを実行する」
 * という設計パターン(湿度・照度の日次レポート評価、サイレントタイムの解禁判定。
 * docs/status-notification-design.md 5章・6-4章)で共通して使うための汎用関数。
 * スケジューラを持たず、次にPOST /sensorを受信したタイミングで判定する設計。
 *
 * @param {string|null} lastRunAt 前回実行した時刻(ISO8601、DB保存値)。未実行ならnull。
 * @param {Date} now 現在時刻
 * @param {number} hour 基準時刻の時(0〜23)
 * @param {number} minute 基準時刻の分(0〜59)
 * @returns {boolean} 今回実行すべきならtrue
 */
export function hasPassedDailyMarker(lastRunAt, now, hour, minute) {
  const todayMarker = new Date(now);
  todayMarker.setHours(hour, minute, 0, 0);

  // まだ本日の基準時刻に達していない → 前回分の結果をそのまま維持する。
  if (now.getTime() < todayMarker.getTime()) return false;

  // 一度も実行したことがない(セットアップ直後など) → 実行する。
  if (!lastRunAt) return true;

  // 前回実行が「本日の基準時刻より前」なら、今日分がまだ未実施ということ。
  return new Date(lastRunAt).getTime() < todayMarker.getTime();
}

/**
 * 湿度・照度の「日次レポート」(docs 3-2, 3-4, 5章)を
 * 今回のPOST /sensor受信時に評価すべきかどうかを判定する(毎日15:00固定)。
 */
export function shouldRunDailyEvaluation(evaluatedAt, now = new Date()) {
  return hasPassedDailyMarker(evaluatedAt, now, 15, 0);
}

/**
 * 日本国内・DST無し前提の固定オフセット(+9時間)でJSTに変換した上で、
 * その月(1〜12)を返す。土壌水分の季節別閾値判定(docs 3-3章、
 * utils/plantStatus.jsのresolveSoilStatus)で使う。
 *
 * サーバーを動かしているマシンのタイムゾーン設定に依存させたくないため
 * (UTC環境で動かしても常に日本時間としての「今月」を取得できるように)、
 * 照度の昼間判定(server/controllers/sensorController.jsのSQL)と同じ
 * 「+9時間固定オフセット」の考え方をJavaScript側でも踏襲している。
 */
export function getMonthInJst(date) {
  const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
  const jstDate = new Date(date.getTime() + JST_OFFSET_MS);
  return jstDate.getUTCMonth() + 1;
}

/**
 * 今が「サイレントタイム」(通知を保留する時間帯、docs 6-4章)かどうかを判定する。
 * start_time〜end_timeが日をまたぐ場合(例: 20:00〜06:00)にも対応する。
 *
 * @param {Date} now 現在時刻
 * @param {string} startTime "HH:MM"形式(例: "20:00")
 * @param {string} endTime "HH:MM"形式(例: "06:00")
 * @returns {boolean}
 */
export function isWithinSilentTime(now, startTime, endTime) {
  const start = parseHourMinute(startTime);
  const end = parseHourMinute(endTime);
  if (!start || !end) return false; // 不正な設定値の場合は安全側(常に通知する)に倒す

  const startMinutes = start.hour * 60 + start.minute;
  const endMinutes = end.hour * 60 + end.minute;
  const nowMinutes = now.getHours() * 60 + now.getMinutes();

  if (startMinutes === endMinutes) return false; // 開始=終了は「無効」扱い

  if (startMinutes < endMinutes) {
    // 日をまたがない範囲(例: 09:00〜17:00)
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  // 日をまたぐ範囲(例: 20:00〜06:00)
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}
