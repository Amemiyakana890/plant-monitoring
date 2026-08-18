import { MONSTERA_THRESHOLDS } from './plantStatus.js';

/**
 * 植物種カタログ(docs/status-notification-design.md 9章「複数植物対応時、
 * species_thresholdsをどう管理・編集させるか」の第一段階の実装)。
 *
 * v1はDBテーブルではなく、この固定カタログとして持たせている。
 * 理由: 現時点では植物種を追加・編集する管理画面までは作らず、
 * あらかじめ用意した種類から選ぶだけの運用にするため
 * (「植物登録画面(F-08)」「植物切り替え機能」の実装に合わせて追加)。
 * 将来、利用者自身が植物種を追加できるようにする場合は、この定数を
 * DBテーブル + 管理APIに置き換える。そのときも呼び出し側
 * (getSpeciesThresholds等)のインターフェースは変えずに済むようにしてある。
 */
export const SPECIES_CATALOG = {
  monstera: {
    key: 'monstera',
    name: 'モンステラ',
    scientificName: 'サトイモ科モンステラ属',
    thresholds: MONSTERA_THRESHOLDS,
  },
};

export const DEFAULT_SPECIES_KEY = 'monstera';

/** カタログの一覧を配列で返す(GET /species向け)。 */
export function listSpecies() {
  return Object.values(SPECIES_CATALOG).map(({ key, name, scientificName }) => ({
    key,
    name,
    scientific_name: scientificName,
  }));
}

/** 指定したkeyがカタログに存在するかどうか。 */
export function isValidSpeciesKey(speciesKey) {
  return Object.prototype.hasOwnProperty.call(SPECIES_CATALOG, speciesKey);
}

/**
 * 植物のspecies_keyから閾値プロファイルを引く。
 * 未設定(null)・カタログに無いkeyの場合はデフォルト種(モンステラ)にフォール
 * バックする(このマイグレーション以前に作成された植物にはspecies_keyが
 * 無いため、既存の挙動を変えないためのフォールバック)。
 */
export function getSpeciesThresholds(speciesKey) {
  return (SPECIES_CATALOG[speciesKey] ?? SPECIES_CATALOG[DEFAULT_SPECIES_KEY]).thresholds;
}

/** 植物のspecies_keyからカタログ情報(表示用)を引く。同じくフォールバックあり。 */
export function getSpeciesInfo(speciesKey) {
  const entry = SPECIES_CATALOG[speciesKey] ?? SPECIES_CATALOG[DEFAULT_SPECIES_KEY];
  return { key: entry.key, name: entry.name, scientific_name: entry.scientificName };
}
