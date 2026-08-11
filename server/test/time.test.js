import { test } from 'node:test';
import assert from 'node:assert/strict';

import { toSqliteTimestamp, shouldRunDailyEvaluation } from '../utils/time.js';

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
