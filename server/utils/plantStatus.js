/**
 * 土壌水分値から植物の状態(status)を判定する(設計書5-7)。
 *   healthy(元気です)   : soil >= 40
 *   thirsty(少し乾いています) : 20 <= soil < 40
 *   dry(乾燥しています)  : soil < 20
 *
 * NOTE: 季節別閾値・継続時間・水やり緩和を考慮した版は下部の
 * resolveSoilStatus()を参照。この determineStatus() 自体は
 * 「瞬間値だけを見る」古い版としてテスト・後方互換のために残しているが、
 * 実際のセンサー受信処理(server/controllers/sensorController.js)からは
 * resolveSoilStatus()を呼ぶよう切り替えている。
 */
export function determineStatus(soil) {
  if (soil >= 40) return 'healthy';
  if (soil >= 20) return 'thirsty';
  return 'dry';
}

// 植物種ごとの閾値プロファイル(docs/status-notification-design.md 3-1〜3-4章)。
//
// v1はモンステラ1種のみを扱うが、植物登録画面(F-08)・植物切り替え機能の
// 実装に伴い、閾値を「渡された値を使うだけ」の関数群に変更した
// (以前はモンステラの数値がすべての判定関数に直接埋め込まれていた)。
// 実際に植物ごとの値を引くカタログは server/utils/speciesCatalog.js を参照。
// このファイルはあくまで「プロファイルを渡されたら判定する」ロジックの置き場所。
//
// MONSTERA_THRESHOLDSはモンステラの実測に基づく値そのもの
// (これまでの数値から変更なし)。デフォルト・後方互換用としてここに残し、
// speciesCatalog.jsがこれをそのままカタログに登録する形にしている。
export const MONSTERA_THRESHOLDS = {
  temperature: { healthyMin: 18, healthyMax: 30, dangerMin: 10, dangerMax: 35 },
  // humidity: 当初「適正60〜80%」としていたが、市販の育成ガイド(一般的な
  // モンステラの適正湿度は40〜60%程度とされることが多い)を参考に、健康域を
  // 40〜60%へ下方修正した(実測データではなく公開情報に基づく暫定的な調整。
  // 詳細な経緯・今後の再検証方針は docs/status-notification-design.md 3-2章
  // を参照。周囲の栽培経験者への確認や複数の情報源との照合も踏まえて、
  // 改めて数値を見直す予定)。
  // 元の閾値からの相対的な帯の幅(healthy帯20pt、低温側caution帯20pt、
  // 高温側caution帯10pt)はそのまま維持し、全体を20pt下にシフトしている。
  humidity: { healthyMin: 40, healthyMax: 60, needsCareMin: 20, needsCareMax: 70 },
  illuminance: { healthyMin: 1000, cautionMin: 500 },
  soil: {
    // 夏(6〜9月): 蒸散が多く乾きやすいため、他の季節より高めの閾値。
    summer: { healthy: 40, needsCare: 20 }, // 注意ゾーン: 20% <= soil < 40%
    // 冬(12〜2月): 休眠期で水やり頻度を落とすため、低めの閾値。
    winter: { healthy: 30, needsCare: 15 }, // 注意ゾーン: 15% <= soil < 30%
    // 春・秋(上記以外の月): 夏と冬の中間的な閾値。
    default: { healthy: 35, needsCare: 18 }, // 注意ゾーン: 18% <= soil < 35%
  },
};

const SUMMER_MONTHS = [6, 7, 8, 9];
const WINTER_MONTHS = [12, 1, 2];

/** 指定した月(1〜12)が季節別閾値のどの区分(夏/冬/春秋)に該当するかを返す。 */
export function getSoilSeasonForMonth(month) {
  if (SUMMER_MONTHS.includes(month)) return 'summer';
  if (WINTER_MONTHS.includes(month)) return 'winter';
  return 'default';
}

/** 指定した月(1〜12)・閾値プロファイルから、季節別の土壌水分閾値を返す。 */
export function getSeasonalSoilThresholds(month, thresholds = MONSTERA_THRESHOLDS) {
  return thresholds.soil[getSoilSeasonForMonth(month)];
}

/**
 * 土壌水分の現在値が、指定した月の季節別閾値でどのゾーンにあるかを判定する。
 *   healthy         : 季節別のhealthy閾値以上
 *   caution_zone    : healthy未満〜needsCare以上(継続時間で healthy→thirsty に格上げ)
 *   needs_care_zone : 季節別のneedsCare閾値未満(水やり緩和が無ければ即座にdry)
 */
export function classifySoilZone(soil, month, thresholds = MONSTERA_THRESHOLDS) {
  const { healthy, needsCare } = getSeasonalSoilThresholds(month, thresholds);
  if (soil >= healthy) return 'healthy';
  if (soil < needsCare) return 'needs_care_zone';
  return 'caution_zone';
}

const SIX_HOURS_MS = 6 * 60 * 60 * 1000;
const SOIL_WATERING_RELIEF_WINDOW_MS = 2 * 60 * 60 * 1000;

/**
 * 季節別閾値・継続時間・水やり緩和を考慮した土壌水分ステータスを算出する
 * (docs/status-notification-design.md 3-3章)。
 *
 * ルール:
 * - healthyゾーン: 即座に'healthy'(継続時間の記録もリセット)。
 * - caution_zone: ゾーンに入ってすぐは見た目上'healthy'のまま
 *   (バッジ・通知とも据え置き)。6時間以上継続して初めて'thirsty'に切り替わる。
 * - needs_care_zone: 原則即座に'dry'。ただし前回の水やりから2時間以内なら、
 *   センサーの応答遅れ・水が浸透しきっていないだけの可能性が高いため
 *   'thirsty'に緩和する。
 *
 * @param {object} params
 * @param {number} params.soil 現在の土壌水分(%)
 * @param {number} params.month 現在の月(1〜12、JST基準。utils/time.jsのgetMonthInJst参照)
 * @param {string|null} params.previousCautionSince 前回caution_zoneに入り続けている開始時刻(ISO8601)
 * @param {Date} params.now 現在時刻
 * @param {string|null} params.lastWateredAt 直近の水やり記録時刻(ISO8601、docs 4-2章)。未記録ならnull。
 * @param {object} [params.thresholds] 植物種ごとの閾値プロファイル(省略時はモンステラ)
 * @returns {{ status: 'healthy'|'thirsty'|'dry', cautionSince: Date|null }}
 */
export function resolveSoilStatus({
  soil,
  month,
  previousCautionSince,
  now,
  lastWateredAt,
  thresholds = MONSTERA_THRESHOLDS,
}) {
  const zone = classifySoilZone(soil, month, thresholds);

  if (zone === 'healthy') {
    return { status: 'healthy', cautionSince: null };
  }

  if (zone === 'needs_care_zone') {
    if (lastWateredAt) {
      const sinceWateredMs = now.getTime() - new Date(lastWateredAt).getTime();
      // sinceWateredMs < 0 は時計のズレ等で「未来」になったケース。安全側
      // (緩和しない="dry"のまま)に倒す。
      if (sinceWateredMs >= 0 && sinceWateredMs < SOIL_WATERING_RELIEF_WINDOW_MS) {
        return { status: 'thirsty', cautionSince: null }; // 水やり緩和
      }
    }
    return { status: 'dry', cautionSince: null };
  }

  // caution_zone: 継続時間で healthy→thirsty を決める。
  // 初めてゾーンに入った瞬間(previousCautionSinceがnull)はcautionSinceを今の時刻にする。
  const since = previousCautionSince ? new Date(previousCautionSince) : now;
  const elapsedMs = now.getTime() - since.getTime();
  const status = elapsedMs >= SIX_HOURS_MS ? 'thirsty' : 'healthy';

  return { status, cautionSince: since };
}

// ここから下、温度・湿度・照度の判定ロジック(docs/status-notification-design.md 3-1, 3-2, 3-4)。
// soilとは値の意味も判定方式(継続時間 vs 日次平均)も異なるため、
// 'healthy' / 'caution' / 'needs_care' という共通の3段階名で統一している
// (soilの'healthy'/'thirsty'/'dry'とは別語彙。既存のplants.statusはsoil専用のまま変更していない)。

const THIRTY_MINUTES_MS = 30 * 60 * 1000;
const TWO_HOURS_MS = 2 * 60 * 60 * 1000;

/**
 * 温度の現在値がどのゾーンにあるかを判定する(docs 3-1)。
 *   healthy      : thresholds.temperature.healthyMin〜healthyMax(適正)
 *   caution_zone : 上記の外側だが危険域ではない(継続時間で healthy→caution→needs_care と格上げ)
 *   danger       : dangerMin未満 または dangerMax以上(継続時間を問わず即座にneeds_care)
 *
 * 元のdocs記載では「10〜15℃」がcaution_zoneにもdangerにも該当しない
 * 抜け穴になっていたため、caution_zoneの下限をhealthyMinではなくdangerMinまで
 * 広げて埋めている(この関数を実装する過程で発見・修正)。
 */
export function classifyTemperatureZone(temperature, thresholds = MONSTERA_THRESHOLDS) {
  const { healthyMin, healthyMax, dangerMin, dangerMax } = thresholds.temperature;
  if (temperature < dangerMin || temperature >= dangerMax) return 'danger';
  if (temperature < healthyMin || temperature > healthyMax) return 'caution_zone';
  return 'healthy';
}

/**
 * 温度の継続時間を考慮した最終的なステータスを算出する(docs 3-1)。
 *
 * @param {number} temperature 現在の温度
 * @param {string|null} previousSince 前回このゾーンに入った時刻(ISO8601)。
 *   healthy状態からcaution_zoneに入った瞬間はnullを渡す想定。
 * @param {Date} now 現在時刻(テスト容易性のため引数で受け取る)
 * @param {object} [thresholds] 植物種ごとの閾値プロファイル(省略時はモンステラ)
 * @returns {{ status: 'healthy'|'caution'|'needs_care', since: Date|null }}
 *   since: caution_zoneに入り続けている開始時刻。healthy/dangerに至った場合はnull
 *   (healthyはリセット、dangerは継続時間を問わないため管理不要)。
 */
export function resolveTemperatureStatus(
  temperature,
  previousSince,
  now = new Date(),
  thresholds = MONSTERA_THRESHOLDS,
) {
  const zone = classifyTemperatureZone(temperature, thresholds);

  if (zone === 'danger') {
    return { status: 'needs_care', since: null };
  }
  if (zone === 'healthy') {
    return { status: 'healthy', since: null };
  }

  // caution_zone: 継続時間で healthy→caution→needs_care を決める。
  // 初めてゾーンに入った瞬間(previousSinceがnull)はsinceを今の時刻にする。
  const since = previousSince ? new Date(previousSince) : now;
  const elapsedMs = now.getTime() - since.getTime();

  let status = 'healthy'; // ゾーンに入ってまだ30分未満は見た目上healthyのまま
  if (elapsedMs >= TWO_HOURS_MS) status = 'needs_care';
  else if (elapsedMs >= THIRTY_MINUTES_MS) status = 'caution';

  return { status, since };
}

/**
 * 湿度の24時間平均から日次ステータスを判定する(docs 3-2)。
 *   healthy    : thresholds.humidity.healthyMin〜healthyMax
 *   caution    : healthyMinとneedsCareMinの間 または healthyMaxとneedsCareMaxの間
 *   needs_care : needsCareMin未満 または needsCareMax超
 */
export function classifyHumidityDailyAverage(averageHumidity, thresholds = MONSTERA_THRESHOLDS) {
  const { healthyMin, healthyMax, needsCareMin, needsCareMax } = thresholds.humidity;
  if (averageHumidity < needsCareMin || averageHumidity > needsCareMax) return 'needs_care';
  if (averageHumidity < healthyMin || averageHumidity > healthyMax) return 'caution';
  return 'healthy';
}

/**
 * 照度の「昼間(6:00〜18:00)平均」から日次ステータスを判定する(docs 3-4)。
 *   healthy    : thresholds.illuminance.healthyMin 以上
 *   caution    : cautionMin以上healthyMin未満
 *   needs_care : cautionMin未満
 *
 * 上限側(直射日光が強すぎるケース)は docs 3-4 のTODO通り今回は未対応。
 */
export function classifyIlluminanceDailyAverage(
  averageIlluminance,
  thresholds = MONSTERA_THRESHOLDS,
) {
  const { healthyMin, cautionMin } = thresholds.illuminance;
  if (averageIlluminance < cautionMin) return 'needs_care';
  if (averageIlluminance < healthyMin) return 'caution';
  return 'healthy';
}
