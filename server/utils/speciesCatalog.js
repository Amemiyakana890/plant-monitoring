import { MONSTERA_THRESHOLDS } from './plantStatus.js';

const PACHIRA_THRESHOLDS = {
  ...MONSTERA_THRESHOLDS,
  humidity: {
    healthyMin: 40,
    healthyMax: 70,
    needsCareMin: 20,
    needsCareMax: 70,
  },
  soil: {
    summer: { healthy: 30, needsCare: 15 },
    winter: { healthy: 30, needsCare: 15 },
    default: { healthy: 30, needsCare: 15 },
  },
};

const SANSEVIERIA_THRESHOLDS = {
  ...MONSTERA_THRESHOLDS,
  humidity: {
    healthyMin: 30,
    healthyMax: 70,
    needsCareMin: 15,
    needsCareMax: 70,
  },
  soil: {
    summer: { healthy: 15, needsCare: 8 },
    winter: { healthy: 15, needsCare: 8 },
    default: { healthy: 15, needsCare: 8 },
  },
};

const POTHOS_THRESHOLDS = {
  ...MONSTERA_THRESHOLDS,
  humidity: {
    healthyMin: 40,
    healthyMax: 70,
    needsCareMin: 20,
    needsCareMax: 70,
  },
  soil: {
    summer: { healthy: 40, needsCare: 20 },
    winter: { healthy: 40, needsCare: 20 },
    default: { healthy: 40, needsCare: 20 },
  },
};

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
    familyName: 'サトイモ科',
    description: '基準',
    careTips: [
      '直射日光を避け、明るい場所で育てましょう。',
      '土の表面が乾いたら、たっぷり水やりをしましょう。',
      '寒さに弱いため、冬は暖かい室内で管理しましょう。',
      '春〜秋の生長期は、適量の液体肥料を与えると生長を促せます。',
    ],
    thresholds: MONSTERA_THRESHOLDS,
  },
  pachira: {
    key: 'pachira',
    name: 'パキラ',
    scientificName: 'アオイ科パキラ属',
    familyName: 'アオイ科',
    description: '乾燥に強い・水にも強い・寒さにやや弱い',
    careTips: [
      '直射日光を避け、明るい場所で育てましょう。',
      '土の表面が乾いてから、たっぷり水やりをしましょう。',
      '寒さに弱いため、冬は暖かい室内で管理しましょう。',
      '春〜秋の生長期は、適量の肥料を与えると生長を促せます。',
    ],
    thresholds: PACHIRA_THRESHOLDS,
  },
  sansevieria: {
    key: 'sansevieria',
    name: 'サンスベリア',
    scientificName: 'キジカクシ科サンセベリア属',
    familyName: 'キジカクシ科',
    description: '4種で最も乾燥・低照度に強い、冬はほぼ断水',
    careTips: [
      '明るい場所を好みますが、夏の強い直射日光には注意しましょう。',
      '土がしっかり乾いてから、水やりをしましょう。',
      '寒さに弱いため、冬は暖かい室内で管理しましょう。',
      '春〜秋の生長期は、適量の肥料を与えましょう。',
    ],
    thresholds: SANSEVIERIA_THRESHOLDS,
  },
  pothos: {
    key: 'pothos',
    name: 'ポトス',
    scientificName: 'サトイモ科ハブカズラ属',
    familyName: 'サトイモ科',
    description: '4種で最も多湿好き、水切れ(特に夏)に弱い',
    careTips: [
      '直射日光を避け、明るい場所で育てましょう。',
      '土の表面が乾いたら、たっぷり水やりをしましょう。',
      '寒さに弱いため、冬は暖かい室内で管理しましょう。',
      '春〜秋の生長期は、適量の液体肥料を与えると生長を促せます。',
    ],
    thresholds: POTHOS_THRESHOLDS,
  },
};

export const DEFAULT_SPECIES_KEY = 'monstera';

/** カタログの一覧を配列で返す(GET /species向け)。 */
export function listSpecies() {
  return Object.values(SPECIES_CATALOG).map(({ key, name, scientificName, familyName, description, careTips, thresholds }) => ({
    key,
    name,
    scientific_name: scientificName,
    family_name: familyName,
    description,
    care_tips: careTips,
    soil_moisture_healthy_min: thresholds.soil.summer.healthy,
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
  return {
    key: entry.key,
    name: entry.name,
    scientific_name: entry.scientificName,
    family_name: entry.familyName,
    description: entry.description,
    care_tips: entry.careTips,
    soil_moisture_healthy_min: entry.thresholds.soil.summer.healthy,
  };
}
