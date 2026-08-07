import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  validateSensorPayload,
  validateDevicePairPayload,
} from '../utils/validation.js';

// 設計書5-4のバリデーション仕様(デバイスペアリング機能実装後):
//   device_id: 正の整数(必須)
//   soil: 0〜100の数値(必須)
//   temperature: -20〜60(任意)
//   humidity: 0〜100(任意)
//   illuminance: 0以上(任意)

test('正常な値の組み合わせはnull(エラーなし)を返す', () => {
  const result = validateSensorPayload({
    device_id: 1,
    temperature: 24.5,
    humidity: 60,
    soil: 40,
    illuminance: 300,
  });
  assert.equal(result, null);
});

test('任意項目(temperature/humidity/illuminance)を省略しても通る', () => {
  const result = validateSensorPayload({ device_id: 1, soil: 50 });
  assert.equal(result, null);
});

test('device_idが数値文字列("1")でも許容する(元実装の挙動に合わせる)', () => {
  const result = validateSensorPayload({ device_id: '1', soil: 50 });
  assert.equal(result, null);
});

test('device_idが0や負数、小数だとエラーになる', () => {
  assert.match(validateSensorPayload({ device_id: 0, soil: 50 }), /device_id/);
  assert.match(validateSensorPayload({ device_id: -1, soil: 50 }), /device_id/);
  assert.match(validateSensorPayload({ device_id: 1.5, soil: 50 }), /device_id/);
});

test('soilが未指定・範囲外だとエラーになる', () => {
  assert.match(validateSensorPayload({ device_id: 1 }), /soil/);
  assert.match(validateSensorPayload({ device_id: 1, soil: -1 }), /soil/);
  assert.match(validateSensorPayload({ device_id: 1, soil: 101 }), /soil/);
});

test('temperatureが範囲外(-20〜60の外)だとエラーになる', () => {
  const result = validateSensorPayload({ device_id: 1, soil: 50, temperature: 61 });
  assert.match(result, /temperature/);
});

test('humidityが範囲外(0〜100の外)だとエラーになる', () => {
  const result = validateSensorPayload({ device_id: 1, soil: 50, humidity: 150 });
  assert.match(result, /humidity/);
});

test('illuminanceが負数だとエラーになる', () => {
  const result = validateSensorPayload({ device_id: 1, soil: 50, illuminance: -1 });
  assert.match(result, /illuminance/);
});

test('soilがNaNや文字列だとエラーになる(数値必須)', () => {
  assert.match(validateSensorPayload({ device_id: 1, soil: NaN }), /soil/);
  assert.match(validateSensorPayload({ device_id: 1, soil: '50' }), /soil/);
});

// POST /devices/pair (設計書5-3)のバリデーション

test('device_name/mac_addressが正しければnullを返す', () => {
  const result = validateDevicePairPayload({
    device_name: 'Plant Monitor 01',
    mac_address: 'AA:BB:CC:DD:EE:FF',
  });
  assert.equal(result, null);
});

test('device_nameが空文字・未指定だとエラーになる', () => {
  assert.match(
    validateDevicePairPayload({ device_name: '', mac_address: 'AA:BB:CC:DD:EE:FF' }),
    /device_name/,
  );
  assert.match(
    validateDevicePairPayload({ mac_address: 'AA:BB:CC:DD:EE:FF' }),
    /device_name/,
  );
});

test('mac_addressの形式が不正だとエラーになる', () => {
  assert.match(
    validateDevicePairPayload({ device_name: 'Plant Monitor 01', mac_address: 'invalid' }),
    /mac_address/,
  );
  assert.match(
    validateDevicePairPayload({ device_name: 'Plant Monitor 01', mac_address: 'AA:BB:CC:DD:EE' }),
    /mac_address/,
  );
});
