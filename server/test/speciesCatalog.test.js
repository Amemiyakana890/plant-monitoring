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

test('listSpecies: カタログの一覧を返す(v1はモンステラ1件)', () => {
  const list = listSpecies();
  assert.equal(list.length, 1);
  assert.deepEqual(list[0], {
    key: 'monstera',
    name: 'モンステラ',
    scientific_name: 'サトイモ科モンステラ属',
  });
});

test('isValidSpeciesKey: カタログに存在するkeyのみtrue', () => {
  assert.equal(isValidSpeciesKey('monstera'), true);
  assert.equal(isValidSpeciesKey('unknown_species'), false);
  assert.equal(isValidSpeciesKey(''), false);
});

test('getSpeciesThresholds: monsteraを指定するとMONSTERA_THRESHOLDSを返す', () => {
  assert.equal(getSpeciesThresholds('monstera'), MONSTERA_THRESHOLDS);
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
  });
  assert.deepEqual(getSpeciesInfo(null), getSpeciesInfo(DEFAULT_SPECIES_KEY));
});

test('SPECIES_CATALOG: モンステラのthresholdsはplantStatus.jsのMONSTERA_THRESHOLDSと同一参照', () => {
  // カタログが独自に閾値を持たず、plantStatus.js側の定義をそのまま使っている
  // ことを確認する(数値の二重管理を防ぐための設計)。
  assert.equal(SPECIES_CATALOG.monstera.thresholds, MONSTERA_THRESHOLDS);
});
