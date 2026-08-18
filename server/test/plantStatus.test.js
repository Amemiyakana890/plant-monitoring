import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  determineStatus,
  getSeasonalSoilThresholds,
  classifySoilZone,
  resolveSoilStatus,
  classifyTemperatureZone,
  resolveTemperatureStatus,
  classifyHumidityDailyAverage,
  classifyIlluminanceDailyAverage,
  MONSTERA_THRESHOLDS,
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

// --- 土壌水分の季節別閾値・継続時間・水やり緩和(docs/status-notification-design.md 3-3) ---

test('季節別閾値: 夏(6〜9月)は40/20、冬(12〜2月)は30/15、それ以外は35/18', () => {
  for (const month of [6, 7, 8, 9]) {
    assert.deepEqual(getSeasonalSoilThresholds(month), { healthy: 40, needsCare: 20 });
  }
  for (const month of [12, 1, 2]) {
    assert.deepEqual(getSeasonalSoilThresholds(month), { healthy: 30, needsCare: 15 });
  }
  for (const month of [3, 4, 5, 10, 11]) {
    assert.deepEqual(getSeasonalSoilThresholds(month), { healthy: 35, needsCare: 18 });
  }
});

test('classifySoilZone: 夏(7月)の境界値', () => {
  assert.equal(classifySoilZone(40, 7), 'healthy');
  assert.equal(classifySoilZone(39.9, 7), 'caution_zone');
  assert.equal(classifySoilZone(20, 7), 'caution_zone');
  assert.equal(classifySoilZone(19.9, 7), 'needs_care_zone');
});

test('classifySoilZone: 冬(1月)の境界値', () => {
  assert.equal(classifySoilZone(30, 1), 'healthy');
  assert.equal(classifySoilZone(29.9, 1), 'caution_zone');
  assert.equal(classifySoilZone(15, 1), 'caution_zone');
  assert.equal(classifySoilZone(14.9, 1), 'needs_care_zone');
});

test('classifySoilZone: 春秋(4月)の境界値', () => {
  assert.equal(classifySoilZone(35, 4), 'healthy');
  assert.equal(classifySoilZone(34.9, 4), 'caution_zone');
  assert.equal(classifySoilZone(18, 4), 'caution_zone');
  assert.equal(classifySoilZone(17.9, 4), 'needs_care_zone');
});

test('resolveSoilStatus: healthyゾーンは即座にhealthy、継続時間もリセットされる', () => {
  const result = resolveSoilStatus({
    soil: 50,
    month: 7,
    previousCautionSince: '2026-08-11T00:00:00Z',
    now: new Date('2026-08-11T12:00:00Z'),
    lastWateredAt: null,
  });
  assert.equal(result.status, 'healthy');
  assert.equal(result.cautionSince, null);
});

test('resolveSoilStatus: caution_zoneに入って6時間未満はまだhealthy扱い', () => {
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T05:59:00Z'); // 5時間59分後
  const result = resolveSoilStatus({
    soil: 30, // 夏: caution_zone (20<=30<40)
    month: 7,
    previousCautionSince: enteredAt.toISOString(),
    now,
    lastWateredAt: null,
  });
  assert.equal(result.status, 'healthy');
});

test('resolveSoilStatus: caution_zoneに6時間以上継続でthirstyに切り替わる', () => {
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T06:00:01Z'); // 6時間1秒後
  const result = resolveSoilStatus({
    soil: 30,
    month: 7,
    previousCautionSince: enteredAt.toISOString(),
    now,
    lastWateredAt: null,
  });
  assert.equal(result.status, 'thirsty');
});

test('resolveSoilStatus: needs_care_zoneは水やり記録が無ければ即座にdry', () => {
  const result = resolveSoilStatus({
    soil: 10, // 夏: needs_care_zone (<20)
    month: 7,
    previousCautionSince: null,
    now: new Date('2026-08-11T12:00:00Z'),
    lastWateredAt: null,
  });
  assert.equal(result.status, 'dry');
  assert.equal(result.cautionSince, null);
});

test('resolveSoilStatus: needs_care_zoneでも水やりから2時間以内ならthirstyに緩和', () => {
  const now = new Date('2026-08-11T12:00:00Z');
  const wateredAt = new Date('2026-08-11T10:30:00Z'); // 1時間30分前
  const result = resolveSoilStatus({
    soil: 10,
    month: 7,
    previousCautionSince: null,
    now,
    lastWateredAt: wateredAt.toISOString(),
  });
  assert.equal(result.status, 'thirsty');
});

test('resolveSoilStatus: 水やりから2時間を過ぎたらneeds_care_zoneは緩和されずdryに戻る', () => {
  const now = new Date('2026-08-11T12:00:00Z');
  const wateredAt = new Date('2026-08-11T09:59:00Z'); // 2時間1分前
  const result = resolveSoilStatus({
    soil: 10,
    month: 7,
    previousCautionSince: null,
    now,
    lastWateredAt: wateredAt.toISOString(),
  });
  assert.equal(result.status, 'dry');
});

test('resolveSoilStatus: caution_zoneには水やり緩和を適用しない(6時間継続のルールのみ)', () => {
  // 水やり直後(5分前)でも、caution_zoneでは緩和判定自体を行わないため、
  // 6時間未満ならhealthy、6時間以上ならthirstyという通常のルールのまま。
  const enteredAt = new Date('2026-08-11T00:00:00Z');
  const now = new Date('2026-08-11T06:00:01Z');
  const wateredAt = new Date('2026-08-11T05:55:00Z'); // 5分前
  const result = resolveSoilStatus({
    soil: 30,
    month: 7,
    previousCautionSince: enteredAt.toISOString(),
    now,
    lastWateredAt: wateredAt.toISOString(),
  });
  assert.equal(result.status, 'thirsty'); // 緩和されずthirstyのまま
});

test('resolveSoilStatus: 未来の水やり時刻(時計のズレ)は緩和しない安全側に倒す', () => {
  const now = new Date('2026-08-11T12:00:00Z');
  const wateredAt = new Date('2026-08-11T12:05:00Z'); // 5分後(未来)
  const result = resolveSoilStatus({
    soil: 10,
    month: 7,
    previousCautionSince: null,
    now,
    lastWateredAt: wateredAt.toISOString(),
  });
  assert.equal(result.status, 'dry');
});

// --- 植物種ごとの閾値パラメータ化(F-08・植物切り替え機能) ---
// デフォルト引数(MONSTERA_THRESHOLDS)を省略した場合の挙動は上記の各テストで
// 既に確認済みなので、ここでは「別の閾値を明示的に渡した場合に、その値が
// 実際に反映されるか」だけを確認する(パラメータ化そのものの動作確認)。

test('classifyTemperatureZone: 異なる閾値プロファイルを渡すと判定が変わる', () => {
  const wideRangeThresholds = {
    temperature: { healthyMin: 5, healthyMax: 40, dangerMin: 0, dangerMax: 45 },
  };
  // モンステラの閾値だと35℃はdangerだが、耐暑性の高い植物のプロファイルなら
  // healthyになる、という想定のテスト。
  assert.equal(classifyTemperatureZone(35, MONSTERA_THRESHOLDS), 'danger');
  assert.equal(classifyTemperatureZone(35, wideRangeThresholds), 'healthy');
});

test('classifyHumidityDailyAverage: 異なる閾値プロファイルを渡すと判定が変わる', () => {
  const highHumidityLovingThresholds = {
    humidity: { healthyMin: 70, healthyMax: 95, needsCareMin: 50, needsCareMax: 100 },
  };
  // モンステラの閾値だと85%はcautionだが、多湿を好む植物のプロファイルなら
  // healthyになる、という想定のテスト。
  assert.equal(classifyHumidityDailyAverage(85, MONSTERA_THRESHOLDS), 'caution');
  assert.equal(classifyHumidityDailyAverage(85, highHumidityLovingThresholds), 'healthy');
});

test('classifyIlluminanceDailyAverage: 異なる閾値プロファイルを渡すと判定が変わる', () => {
  const shadeLovingThresholds = {
    illuminance: { healthyMin: 200, cautionMin: 50 },
  };
  // モンステラの閾値だと700luxはcautionだが、日陰を好む植物のプロファイル
  // なら十分healthy、という想定のテスト。
  assert.equal(classifyIlluminanceDailyAverage(700, MONSTERA_THRESHOLDS), 'caution');
  assert.equal(classifyIlluminanceDailyAverage(700, shadeLovingThresholds), 'healthy');
});

test('getSeasonalSoilThresholds / classifySoilZone: 異なる閾値プロファイルを渡すと判定が変わる', () => {
  const droughtTolerantThresholds = {
    soil: {
      summer: { healthy: 15, needsCare: 5 },
      winter: { healthy: 10, needsCare: 3 },
      default: { healthy: 12, needsCare: 4 },
    },
  };
  assert.deepEqual(getSeasonalSoilThresholds(7, droughtTolerantThresholds), {
    healthy: 15,
    needsCare: 5,
  });
  // モンステラの閾値だと夏のsoil=10はneeds_care_zoneだが、乾燥に強い植物の
  // プロファイルなら同じ10%でもcaution_zone(または適正)になる、という想定。
  assert.equal(classifySoilZone(10, 7, MONSTERA_THRESHOLDS), 'needs_care_zone');
  assert.equal(classifySoilZone(10, 7, droughtTolerantThresholds), 'caution_zone');
});
