import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  determineStatus,
  classifyTemperatureZone,
  resolveTemperatureStatus,
  classifyHumidityDailyAverage,
  classifyIlluminanceDailyAverage,
} from '../utils/plantStatus.js';

// 設計書5-7の閾値定義:
//   healthy(元気です)   : soil >= 40
//   thirsty(少し乾いています) : 20 <= soil < 40
//   dry(乾燥しています)  : soil < 20

test('soilが40以上ならhealthy', () => {
  assert.equal(determineStatus(40), 'healthy');
  assert.equal(determineStatus(41), 'healthy');
  assert.equal(determineStatus(100), 'healthy');
});

test('soilが20以上40未満ならthirsty', () => {
  assert.equal(determineStatus(20), 'thirsty');
  assert.equal(determineStatus(39), 'thirsty');
  assert.equal(determineStatus(39.9), 'thirsty');
});

test('soilが20未満ならdry', () => {
  assert.equal(determineStatus(19), 'dry');
  assert.equal(determineStatus(19.9), 'dry');
  assert.equal(determineStatus(0), 'dry');
});

// 境界値(40と20ちょうど)は「以上」側に倒れる仕様なので、
// 特に間違えやすい境界だけ明示的に確認しておく。
test('境界値ちょうど(40, 20)は上位の状態になる', () => {
  assert.equal(determineStatus(40), 'healthy'); // thirstyではない
  assert.equal(determineStatus(20), 'thirsty'); // dryではない
});

// --- 温度(docs/status-notification-design.md 3-1) ---

test('温度: 18〜30℃はhealthyゾーン', () => {
  assert.equal(classifyTemperatureZone(18), 'healthy');
  assert.equal(classifyTemperatureZone(24), 'healthy');
  assert.equal(classifyTemperatureZone(30), 'healthy');
});

test('温度: 10〜18℃未満・30℃超〜35℃未満はcaution_zone(元のdocsの抜け穴だった10〜15℃も含む)', () => {
  assert.equal(classifyTemperatureZone(10), 'caution_zone');
  assert.equal(classifyTemperatureZone(12), 'caution_zone');
  assert.equal(classifyTemperatureZone(17.9), 'caution_zone');
  assert.equal(classifyTemperatureZone(30.1), 'caution_zone');
  assert.equal(classifyTemperatureZone(34.9), 'caution_zone');
});

test('温度: 10℃未満・35℃以上はdanger', () => {
  assert.equal(classifyTemperatureZone(9.9), 'danger');
  assert.equal(classifyTemperatureZone(0), 'danger');
  assert.equal(classifyTemperatureZone(35), 'danger');
  assert.equal(classifyTemperatureZone(40), 'danger');
});

test('温度: dangerは継続時間を問わず即座にneeds_care', () => {
  const result = resolveTemperatureStatus(36, null, new Date('2026-08-11T00:00:00Z'));
  assert.equal(result.status, 'needs_care');
  assert.equal(result.since, null);
});

test('温度: healthyゾーンに戻るとsinceがリセットされる', () => {
  const result = resolveTemperatureStatus(24, '2026-08-10T00:00:00Z', new Date('2026-08-11T00:00:00Z'));
  assert.equal(result.status, 'healthy');
  assert.equal(result.since, null);
});

test('温度: caution_zoneに入って30分未満はまだhealthy扱い', () => {
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T00:20:00Z'); // 20分後
  const result = resolveTemperatureStatus(15, enteredAt.toISOString(), now);
  assert.equal(result.status, 'healthy');
});

test('温度: caution_zoneに30分以上2時間未満継続でcaution', () => {
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T00:31:00Z'); // 31分後
  const result = resolveTemperatureStatus(15, enteredAt.toISOString(), now);
  assert.equal(result.status, 'caution');
});

test('温度: caution_zoneに2時間以上継続でneeds_care', () => {
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T02:01:00Z'); // 2時間1分後
  const result = resolveTemperatureStatus(15, enteredAt.toISOString(), now);
  assert.equal(result.status, 'needs_care');
});

// --- 湿度(docs/status-notification-design.md 3-2, 24時間平均) ---

test('湿度: 60〜80%はhealthy', () => {
  assert.equal(classifyHumidityDailyAverage(60), 'healthy');
  assert.equal(classifyHumidityDailyAverage(70), 'healthy');
  assert.equal(classifyHumidityDailyAverage(80), 'healthy');
});

test('湿度: 40〜60%未満・80%超〜90%はcaution', () => {
  assert.equal(classifyHumidityDailyAverage(40), 'caution');
  assert.equal(classifyHumidityDailyAverage(59.9), 'caution');
  assert.equal(classifyHumidityDailyAverage(85), 'caution');
  assert.equal(classifyHumidityDailyAverage(90), 'caution');
});

test('湿度: 40%未満・90%超はneeds_care', () => {
  assert.equal(classifyHumidityDailyAverage(39.9), 'needs_care');
  assert.equal(classifyHumidityDailyAverage(0), 'needs_care');
  assert.equal(classifyHumidityDailyAverage(90.1), 'needs_care');
  assert.equal(classifyHumidityDailyAverage(100), 'needs_care');
});

// --- 照度(docs/status-notification-design.md 3-4, 昼間平均) ---

test('照度: 1000〜10000luxはhealthy', () => {
  assert.equal(classifyIlluminanceDailyAverage(1000), 'healthy');
  assert.equal(classifyIlluminanceDailyAverage(5000), 'healthy');
  assert.equal(classifyIlluminanceDailyAverage(50000), 'healthy'); // 上限側は今回未対応(docs 3-4のTODO)
});

test('照度: 500〜1000lux未満はcaution', () => {
  assert.equal(classifyIlluminanceDailyAverage(500), 'caution');
  assert.equal(classifyIlluminanceDailyAverage(999), 'caution');
});

test('照度: 500lux未満はneeds_care', () => {
  assert.equal(classifyIlluminanceDailyAverage(499.9), 'needs_care');
  assert.equal(classifyIlluminanceDailyAverage(0), 'needs_care');
});
