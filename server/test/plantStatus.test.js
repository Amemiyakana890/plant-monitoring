import { test } from 'node:test';
import assert from 'node:assert/strict';

import { determineStatus } from '../utils/plantStatus.js';

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
