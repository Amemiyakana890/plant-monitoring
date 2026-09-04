import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  SPECIES_CATALOG,
  DEFAULT_SPECIES_KEY,
  listSpecies,
  isValidSpeciesKey,
  getSpeciesThresholds,
  getSpeciesInfo,
} from '../utils/speciesCatalog.js';
import { MONSTERA_THRESHOLDS } from '../utils/plantStatus.js';

test('listSpecies: 4種のカタログと土壌水分閾値を返す', () => {
  const list = listSpecies();
  assert.deepEqual(list.map((species) => species.key), [
    'monstera',
    'pachira',
    'sansevieria',
    'pothos',
  ]);
  assert.deepEqual(
    Object.fromEntries(
      list.map((species) => [species.key, species.soil_moisture_healthy_min]),
    ),
    { monstera: 40, pachira: 30, sansevieria: 15, pothos: 40 },
  );
});

test('isValidSpeciesKey: カタログに存在するkeyのみtrue', () => {
  assert.equal(isValidSpeciesKey('monstera'), true);
  assert.equal(isValidSpeciesKey('pachira'), true);
  assert.equal(isValidSpeciesKey('sansevieria'), true);
  assert.equal(isValidSpeciesKey('pothos'), true);
  assert.equal(isValidSpeciesKey('unknown_species'), false);
  assert.equal(isValidSpeciesKey(''), false);
});

test('getSpeciesThresholds: monsteraを指定するとMONSTERA_THRESHOLDSを返す', () => {
  assert.equal(getSpeciesThresholds('monstera'), MONSTERA_THRESHOLDS);
});

test('getSpeciesThresholds: 各植物の土壌水分の健康下限を返す', () => {
  assert.equal(getSpeciesThresholds('pachira').soil.default.healthy, 30);
  assert.equal(getSpeciesThresholds('sansevieria').soil.default.healthy, 15);
  assert.equal(getSpeciesThresholds('pothos').soil.default.healthy, 40);
});

test('getSpeciesThresholds: 各植物の日平均湿度の適正範囲を返す', () => {
  assert.deepEqual(
    Object.fromEntries(
      ['monstera', 'pachira', 'sansevieria', 'pothos'].map((key) => {
        const humidity = getSpeciesThresholds(key).humidity;
        return [key, [humidity.healthyMin, humidity.healthyMax]];
      }),
    ),
    {
      monstera: [40, 70],
      pachira: [40, 70],
      sansevieria: [30, 70],
      pothos: [40, 70],
    },
  );
});

test('getSpeciesThresholds: null・未知のkeyはデフォルト種(モンステラ)にフォールバックする', () => {
  // 移行前(species_key未設定)の植物でも既存の挙動を変えないための重要な仕様。
  assert.equal(getSpeciesThresholds(null), MONSTERA_THRESHOLDS);
  assert.equal(getSpeciesThresholds(undefined), MONSTERA_THRESHOLDS);
  assert.equal(getSpeciesThresholds('unknown_species'), MONSTERA_THRESHOLDS);
});

test('getSpeciesInfo: 表示用の情報を返す(不明なkeyはデフォルト種にフォールバック)', () => {
  assert.deepEqual(getSpeciesInfo('monstera'), {
    key: 'monstera',
    name: 'モンステラ',
    scientific_name: 'サトイモ科モンステラ属',
    family_name: 'サトイモ科',
    family_name: 'サトイモ科',
    description: '基準',
    care_tips: [
      '直射日光を避け、明るい場所で育てましょう。',
      '土の表面が乾いたら、たっぷり水やりをしましょう。',
      '寒さに弱いため、冬は暖かい室内で管理しましょう。',
      '春〜秋の生長期は、適量の液体肥料を与えると生長を促せます。',
    ],
    soil_moisture_healthy_min: 40,
  });
  assert.deepEqual(getSpeciesInfo(null), getSpeciesInfo(DEFAULT_SPECIES_KEY));
});

test('SPECIES_CATALOG: モンステラのthresholdsはplantStatus.jsのMONSTERA_THRESHOLDSと同一参照', () => {
  // カタログが独自に閾値を持たず、plantStatus.js側の定義をそのまま使っている
  // ことを確認する(数値の二重管理を防ぐための設計)。
  assert.equal(SPECIES_CATALOG.monstera.thresholds, MONSTERA_THRESHOLDS);
});
