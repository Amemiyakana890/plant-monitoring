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

test('shouldRunDailyEvaluation: 本日15:00より前は実行しない', () => {
  const now = new Date('2026-08-11T14:59:00');
  assert.equal(shouldRunDailyEvaluation('2026-08-10T15:00:01', now), false);
});

test('shouldRunDailyEvaluation: 未評価(null)なら15:00以降に実行する', () => {
  const now = new Date('2026-08-11T15:00:30');
  assert.equal(shouldRunDailyEvaluation(null, now), true);
});

test('shouldRunDailyEvaluation: 前回評価が本日15:00より前なら実行する', () => {
  const now = new Date('2026-08-11T15:05:00');
  assert.equal(shouldRunDailyEvaluation('2026-08-10T15:03:00', now), true);
});

test('shouldRunDailyEvaluation: 前回評価が本日15:00以降なら実行しない(1日1回に保つ)', () => {
  const now = new Date('2026-08-11T18:00:00');
  assert.equal(shouldRunDailyEvaluation('2026-08-11T15:00:10', now), false);
});

// --- hasPassedDailyMarker(サイレントタイム解禁チェックでも共用する汎用関数) ---

test('hasPassedDailyMarker: 任意の時刻(例: 06:00)でも同じルールで動く', () => {
  const beforeMarker = new Date('2026-08-11T05:59:00');
  const afterMarker = new Date('2026-08-11T06:00:30');
  assert.equal(hasPassedDailyMarker(null, beforeMarker, 6, 0), false);
  assert.equal(hasPassedDailyMarker(null, afterMarker, 6, 0), true);
  assert.equal(
    hasPassedDailyMarker('2026-08-11T06:00:10', afterMarker, 6, 0),
    false, // 今日分はすでに実行済み
  );
  assert.equal(
    hasPassedDailyMarker('2026-08-10T06:00:10', afterMarker, 6, 0),
    true, // 前回は前日分なので今日はまだ
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

test('isWithinSilentTime: 日をまたぐ範囲(20:00〜06:00)で正しく判定する', () => {
  const start = '20:00';
  const end = '06:00';

  assert.equal(isWithinSilentTime(new Date('2026-08-11T21:00:00'), start, end), true);
  assert.equal(isWithinSilentTime(new Date('2026-08-12T03:00:00'), start, end), true);
  assert.equal(isWithinSilentTime(new Date('2026-08-11T19:59:00'), start, end), false);
  assert.equal(isWithinSilentTime(new Date('2026-08-12T06:00:00'), start, end), false); // 終了時刻ちょうどは解禁後
  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00'), start, end), false);
});

test('isWithinSilentTime: 日をまたがない範囲(09:00〜17:00)でも判定できる', () => {
  const start = '09:00';
  const end = '17:00';

  assert.equal(isWithinSilentTime(new Date('2026-08-11T12:00:00'), start, end), true);
  assert.equal(isWithinSilentTime(new Date('2026-08-11T08:59:00'), start, end), false);
  assert.equal(isWithinSilentTime(new Date('2026-08-11T17:00:00'), start, end), false);
});

test('isWithinSilentTime: 開始と終了が同じ場合は常にfalse(無効設定扱い)', () => {
  assert.equal(isWithinSilentTime(new Date('2026-08-11T21:00:00'), '20:00', '20:00'), false);
});

test('isWithinSilentTime: 不正な設定値の場合は安全側(常に通知する=false)に倒す', () => {
  assert.equal(isWithinSilentTime(new Date('2026-08-11T21:00:00'), 'invalid', '06:00'), false);
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
