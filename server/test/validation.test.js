import { test } from 'node:test';
import assert from 'node:assert/strict';

import { validateSensorPayload } from '../utils/validation.js';

// 設計書5-4のバリデーション仕様:
//   plant_id: 正の整数(必須)
//   soil: 0〜100の数値(必須)
//   temperature: -20〜60(任意)
//   humidity: 0〜100(任意)
//   illuminance: 0以上(任意)

test('正常な値の組み合わせはnull(エラーなし)を返す', () => {
  const result = validateSensorPayload({
    plant_id: 1,
    temperature: 24.5,
    humidity: 60,
    soil: 40,
    illuminance: 300,
  });
  assert.equal(result, null);
});

test('任意項目(temperature/humidity/illuminance)を省略しても通る', () => {
  const result = validateSensorPayload({ plant_id: 1, soil: 50 });
  assert.equal(result, null);
});

test('plant_idが数値文字列("1")でも許容する(元実装の挙動に合わせる)', () => {
  const result = validateSensorPayload({ plant_id: '1', soil: 50 });
  assert.equal(result, null);
});

test('plant_idが0や負数、小数だとエラーになる', () => {
  assert.match(validateSensorPayload({ plant_id: 0, soil: 50 }), /plant_id/);
  assert.match(validateSensorPayload({ plant_id: -1, soil: 50 }), /plant_id/);
  assert.match(validateSensorPayload({ plant_id: 1.5, soil: 50 }), /plant_id/);
});

test('soilが未指定・範囲外だとエラーになる', () => {
  assert.match(validateSensorPayload({ plant_id: 1 }), /soil/);
  assert.match(validateSensorPayload({ plant_id: 1, soil: -1 }), /soil/);
  assert.match(validateSensorPayload({ plant_id: 1, soil: 101 }), /soil/);
});

test('temperatureが範囲外(-20〜60の外)だとエラーになる', () => {
  const result = validateSensorPayload({ plant_id: 1, soil: 50, temperature: 61 });
  assert.match(result, /temperature/);
});

test('humidityが範囲外(0〜100の外)だとエラーになる', () => {
  const result = validateSensorPayload({ plant_id: 1, soil: 50, humidity: 150 });
  assert.match(result, /humidity/);
});

test('illuminanceが負数だとエラーになる', () => {
  const result = validateSensorPayload({ plant_id: 1, soil: 50, illuminance: -1 });
  assert.match(result, /illuminance/);
});

test('soilがNaNや文字列だとエラーになる(数値必須)', () => {
  assert.match(validateSensorPayload({ plant_id: 1, soil: NaN }), /soil/);
  assert.match(validateSensorPayload({ plant_id: 1, soil: '50' }), /soil/);
});
