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

// 日本国内・DST無し前提の固定オフセット。サーバーを動かしているマシンの
// システムタイムゾーン設定(例: クラウド・Dockerで一般的なUTC)に依存させたく
// ないため、「+9時間したうえでUTCのgetter/setterを使う」という考え方を
// この ファイル内のJST関連関数すべてで統一している
// (照度の昼間判定(server/controllers/sensorController.jsのSQL)や
// getMonthInJstと同じ考え方)。
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** dateを「JSTとして見た場合の見た目上のDate」に変換する内部ヘルパー。 */
function toJstView(date) {
  return new Date(date.getTime() + JST_OFFSET_MS);
}

/**
 * baseDateと同じ「JST上の日付」で、時刻だけhour:minuteに設定した瞬間を、
 * 実際のUTC基準のDateオブジェクトとして返す内部ヘルパー。
 * 例: baseDateがJSTで2026-08-14 16:38、hour=15,minute=0なら、
 *     「2026-08-14のJST 15:00」に相当する実時刻(UTC 2026-08-14 06:00)を返す。
 */
function jstMarkerAsInstant(baseDate, hour, minute) {
  const jstView = toJstView(baseDate);
  const markerAsJstWallClock = Date.UTC(
    jstView.getUTCFullYear(),
    jstView.getUTCMonth(),
    jstView.getUTCDate(),
    hour,
    minute,
    0,
    0,
  );
  return new Date(markerAsJstWallClock - JST_OFFSET_MS);
}

/**
 * 「1日1回、決まった時刻(JSTのhour:minute)をまたいだタイミングで何かを実行する」
 * という設計パターン(湿度・照度の日次レポート評価、サイレントタイムの解禁判定。
 * docs/status-notification-design.md 5章・6-4章)で共通して使うための汎用関数。
 * スケジューラを持たず、次にPOST /sensorを受信したタイミングで判定する設計。
 *
 * hour:minuteはJST(日本時間)として解釈する。サーバーのシステムタイムゾーンが
 * UTCであっても常にJSTの時刻として扱えるよう、jstMarkerAsInstant()で
 * JST基準の「今日のマーカー時刻」を実時刻に変換してから比較している。
 *
 * @param {string|null} lastRunAt 前回実行した時刻(ISO8601、DB保存値)。未実行ならnull。
 * @param {Date} now 現在時刻
 * @param {number} hour 基準時刻の時(0〜23、JST)
 * @param {number} minute 基準時刻の分(0〜59、JST)
 * @returns {boolean} 今回実行すべきならtrue
 */
export function hasPassedDailyMarker(lastRunAt, now, hour, minute) {
  const todayMarker = jstMarkerAsInstant(now, hour, minute);

  // まだ本日(JST)の基準時刻に達していない → 前回分の結果をそのまま維持する。
  if (now.getTime() < todayMarker.getTime()) return false;

  // 一度も実行したことがない(セットアップ直後など) → 実行する。
  if (!lastRunAt) return true;

  // 前回実行が「本日(JST)の基準時刻より前」なら、今日分がまだ未実施ということ。
  return new Date(lastRunAt).getTime() < todayMarker.getTime();
}

/**
 * 湿度・照度の「日次レポート」(docs 3-2, 3-4, 5章)を
 * 今回のPOST /sensor受信時に評価すべきかどうかを判定する(毎日JST 15:00固定)。
 */
export function shouldRunDailyEvaluation(evaluatedAt, now = new Date()) {
  return hasPassedDailyMarker(evaluatedAt, now, 15, 0);
}

/**
 * 日本国内・DST無し前提の固定オフセット(+9時間)でJSTに変換した上で、
 * その月(1〜12)を返す。土壌水分の季節別閾値判定(docs 3-3章、
 * utils/plantStatus.jsのresolveSoilStatus)で使う。
 */
export function getMonthInJst(date) {
  return toJstView(date).getUTCMonth() + 1;
}

/**
 * 今が「サイレントタイム」(通知を保留する時間帯、docs 6-4章)かどうかを判定する。
 * start_time〜end_timeが日をまたぐ場合(例: 20:00〜06:00)にも対応する。
 * start_time/end_timeはJST(日本時間)として解釈する(hasPassedDailyMarkerと同様、
 * サーバーのシステムタイムゾーンには依存しない)。
 *
 * @param {Date} now 現在時刻
 * @param {string} startTime "HH:MM"形式・JST(例: "20:00")
 * @param {string} endTime "HH:MM"形式・JST(例: "06:00")
 * @returns {boolean}
 */
export function isWithinSilentTime(now, startTime, endTime) {
  const start = parseHourMinute(startTime);
  const end = parseHourMinute(endTime);
  if (!start || !end) return false; // 不正な設定値の場合は安全側(常に通知する)に倒す

  const startMinutes = start.hour * 60 + start.minute;
  const endMinutes = end.hour * 60 + end.minute;

  const jstView = toJstView(now);
  const nowMinutes = jstView.getUTCHours() * 60 + jstView.getUTCMinutes();

  if (startMinutes === endMinutes) return false; // 開始=終了は「無効」扱い

  if (startMinutes < endMinutes) {
    // 日をまたがない範囲(例: 09:00〜17:00)
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  // 日をまたぐ範囲(例: 20:00〜06:00)
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}
