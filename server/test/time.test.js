import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  toSqliteTimestamp,
  shouldRunDailyEvaluation,
  hasPassedDailyMarker,
  parseHourMinute,
  isWithinSilentTime,
  getMonthInJst,
} from '../utils/time.js';

test('toSqliteTimestamp: ミリ秒を含まないUTC文字列になる', () => {
  const date = new Date('2026-08-11T01:08:52.123Z');
  assert.equal(toSqliteTimestamp(date), '2026-08-11T01:08:52Z');
});

// 以下、日時に関するテストはすべて明示的にUTC('...Z')で時刻を書き、
// コメントでJST換算を示す形にしている。テストを実行するマシンの
// システムタイムゾーンに依存せず、常に同じ結果になることを保証するため
// (今回、システムタイムゾーンにJSTでのマーカー判定を依存させてしまっていた
// バグが見つかったため、テスト自体もその再発を防げる書き方に直した)。

test('shouldRunDailyEvaluation: 本日JST15:00より前は実行しない', () => {
  // UTC 2026-08-11T05:59:00Z = JST 2026-08-11 14:59(まだ15:00前)
  const now = new Date('2026-08-11T05:59:00Z');
  assert.equal(shouldRunDailyEvaluation('2026-08-10T06:00:01Z', now), false);
});

test('shouldRunDailyEvaluation: 未評価(null)ならJST15:00以降に実行する', () => {
  // UTC 2026-08-11T06:00:30Z = JST 2026-08-11 15:00:30
  const now = new Date('2026-08-11T06:00:30Z');
  assert.equal(shouldRunDailyEvaluation(null, now), true);
});

test('shouldRunDailyEvaluation: 前回評価が本日JST15:00より前なら実行する', () => {
  // UTC 2026-08-11T06:05:00Z = JST 2026-08-11 15:05
  const now = new Date('2026-08-11T06:05:00Z');
  // 前回評価: UTC 2026-08-10T06:03:00Z = JST 2026-08-10 15:03(前日分)
  assert.equal(shouldRunDailyEvaluation('2026-08-10T06:03:00Z', now), true);
});

test('shouldRunDailyEvaluation: 前回評価が本日JST15:00以降なら実行しない(1日1回に保つ)', () => {
  // UTC 2026-08-11T09:00:00Z = JST 2026-08-11 18:00
  const now = new Date('2026-08-11T09:00:00Z');
  // 前回評価: UTC 2026-08-11T06:00:10Z = JST 2026-08-11 15:00:10(本日分・実施済み)
  assert.equal(shouldRunDailyEvaluation('2026-08-11T06:00:10Z', now), false);
});

// サーバーのシステムタイムゾーンがUTCの環境(クラウド・Docker等でよくある)
// でも正しくJST 15:00を基準に動くことを確認する回帰テスト
// (以前このJST変換が抜けていて、UTC 15:00 = JST深夜0:00に発火するバグがあった)。
test('shouldRunDailyEvaluation: UTC上の時刻がJST 15:00と一致しない時間帯でも誤発火しない', () => {
  // UTC 2026-08-11T15:00:00Z = JST 2026-08-12 00:00(日付が変わった直後)
  // JSTでは まだ当日15:00に達していないので実行しないのが正しい。
  const now = new Date('2026-08-11T15:00:00Z');
  assert.equal(shouldRunDailyEvaluation(null, now), false);
});

// --- hasPassedDailyMarker(サイレントタイム解禁チェックでも共用する汎用関数) ---

test('hasPassedDailyMarker: 任意の時刻(例: JST 06:00)でも同じルールで動く', () => {
  // UTC 2026-08-10T20:59:00Z = JST 2026-08-11 05:59(マーカー前)
  const beforeMarker = new Date('2026-08-10T20:59:00Z');
  // UTC 2026-08-10T21:00:30Z = JST 2026-08-11 06:00:30(マーカー後)
  const afterMarker = new Date('2026-08-10T21:00:30Z');
  assert.equal(hasPassedDailyMarker(null, beforeMarker, 6, 0), false);
  assert.equal(hasPassedDailyMarker(null, afterMarker, 6, 0), true);
  assert.equal(
    hasPassedDailyMarker('2026-08-10T21:00:10Z', afterMarker, 6, 0),
    false, // 今日(JST 8/11)分はすでに実行済み
  );
  assert.equal(
    hasPassedDailyMarker('2026-08-09T21:00:10Z', afterMarker, 6, 0),
    true, // 前回はJST 8/10分なので今日(8/11)はまだ
  );
});

// --- parseHourMinute ---

test('parseHourMinute: "HH:MM"形式を正しく解釈する', () => {
  assert.deepEqual(parseHourMinute('20:00'), { hour: 20, minute: 0 });
  assert.deepEqual(parseHourMinute('06:05'), { hour: 6, minute: 5 });
  assert.deepEqual(parseHourMinute('0:00'), { hour: 0, minute: 0 });
});

test('parseHourMinute: 不正な形式・範囲外はnullになる', () => {
  assert.equal(parseHourMinute('25:00'), null); // 時が範囲外
  assert.equal(parseHourMinute('12:60'), null); // 分が範囲外
  assert.equal(parseHourMinute('invalid'), null);
  assert.equal(parseHourMinute(null), null);
  assert.equal(parseHourMinute(undefined), null);
});

// --- isWithinSilentTime(docs/status-notification-design.md 6-4章) ---
// start_time/end_timeはJSTとして解釈されるため、テストの現在時刻もUTCで
// 明示し、コメントでJST換算を示す(hasPassedDailyMarkerのテストと同じ理由)。

test('isWithinSilentTime: 日をまたぐ範囲(JST 20:00〜06:00)で正しく判定する', () => {
  const start = '20:00';
  const end = '06:00';

  // UTC 2026-08-11T12:00:00Z = JST 2026-08-11 21:00(サイレントタイム中)
  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00Z'), start, end), true);
  // UTC 2026-08-11T18:00:00Z = JST 2026-08-12 03:00(日をまたいでもサイレントタイム中)
  assert.equal(isWithinSilentTime(new Date('2026-08-11T18:00:00Z'), start, end), true);
  // UTC 2026-08-11T10:59:00Z = JST 2026-08-11 19:59(サイレントタイム開始直前)
  assert.equal(isWithinSilentTime(new Date('2026-08-11T10:59:00Z'), start, end), false);
  // UTC 2026-08-11T21:00:00Z = JST 2026-08-12 06:00(終了時刻ちょうどは解禁後)
  assert.equal(isWithinSilentTime(new Date('2026-08-11T21:00:00Z'), start, end), false);
  // UTC 2026-08-11T03:00:00Z = JST 2026-08-11 12:00(日中、サイレントタイム外)
  assert.equal(isWithinSilentTime(new Date('2026-08-11T03:00:00Z'), start, end), false);
});

test('isWithinSilentTime: 日をまたがない範囲(JST 09:00〜17:00)でも判定できる', () => {
  const start = '09:00';
  const end = '17:00';

  // UTC 2026-08-11T03:00:00Z = JST 12:00
  assert.equal(isWithinSilentTime(new Date('2026-08-11T03:00:00Z'), start, end), true);
  // UTC 2026-08-10T23:59:00Z = JST 08:59
  assert.equal(isWithinSilentTime(new Date('2026-08-10T23:59:00Z'), start, end), false);
  // UTC 2026-08-11T08:00:00Z = JST 17:00
  assert.equal(isWithinSilentTime(new Date('2026-08-11T08:00:00Z'), start, end), false);
});

test('isWithinSilentTime: 開始と終了が同じ場合は常にfalse(無効設定扱い)', () => {
  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00Z'), '20:00', '20:00'), false);
});

test('isWithinSilentTime: 不正な設定値の場合は安全側(常に通知する=false)に倒す', () => {
  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00Z'), 'invalid', '06:00'), false);
});

// サーバーのシステムタイムゾーンがUTCでも正しくJST基準で動くことを確認する
// 回帰テスト(以前このJST変換が抜けていて、UTC時刻をそのままJSTかのように
// 扱ってしまうバグがあった)。UTC 20:00〜06:00をそのまま比較すると
// 「JST 20:00〜06:00」のつもりが実際は「JST 05:00〜15:00」になってしまう、
// という間違いを検出できる値を選んでいる。
test('isWithinSilentTime: システムTZ非依存の回帰テスト(UTC基準の誤判定を検出する)', () => {
  // UTC 2026-08-11T10:00:00Z = JST 2026-08-11 19:00。
  // JST基準では19:00はまだサイレントタイム(20:00〜)の外(false)のはずだが、
  // もしUTC時刻をそのまま使う誤実装だと、UTC 10:00は20:00〜06:00の範囲外
  // (=false)なので、この1点だけでは誤実装を判別できない。
  // 判別できる値として、UTC 12:00(JST 21:00、サイレントタイム中のはず)を使う:
  // UTC基準の誤実装だと、UTC 12:00は20:00〜06:00の範囲外なのでfalseを返して
  // しまうが、正しい実装(JST変換あり)ならtrueになる。
  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00Z'), '20:00', '06:00'), true);
});

// --- getMonthInJst(土壌水分の季節別閾値判定で使う、docs 3-3章) ---

test('getMonthInJst: UTCの日中はそのままJSTでも同じ月になる', () => {
  // UTC 2026-08-11T12:00:00Z -> JST 2026-08-11 21:00 (同じ8月)
  assert.equal(getMonthInJst(new Date('2026-08-11T12:00:00Z')), 8);
});

test('getMonthInJst: UTCで月末・JSTでは翌月にまたぐケースを正しく扱う', () => {
  // UTC 2026-08-31T20:00:00Z -> JST 2026-09-01 05:00 (9月に繰り上がる)
  assert.equal(getMonthInJst(new Date('2026-08-31T20:00:00Z')), 9);
  // UTC 2026-08-31T14:00:00Z -> JST 2026-08-31 23:00 (まだ8月のまま)
  assert.equal(getMonthInJst(new Date('2026-08-31T14:00:00Z')), 8);
});

test('getMonthInJst: 年末年始をまたぐケース(12月→1月)', () => {
  // UTC 2026-12-31T20:00:00Z -> JST 2027-01-01 05:00
  assert.equal(getMonthInJst(new Date('2026-12-31T20:00:00Z')), 1);
});
