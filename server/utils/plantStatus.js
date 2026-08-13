/**
 * 土壌水分値から植物の状態(status)を判定する(設計書5-7)。
 *   healthy(元気です)   : soil >= 40
 *   thirsty(少し乾いています) : 20 <= soil < 40
 *   dry(乾燥しています)  : soil < 20
 *
 * 閾値は将来的に植物種ごとに変える可能性があるため(設計書5-7の注記)、
 * ここに集約しておき、変更が必要になったらこの関数だけ直せばよいようにしている。
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

// 土壌水分の季節別閾値・継続時間・水やり緩和(docs/status-notification-design.md 3-3章)。
//
// ★モンステラ専用の暫定値★
// v1は1植物(モンステラ)のみを管理する単独構成のため定数として持たせているが、
// 将来の複数植物対応(企画書11章)時には、この閾値テーブル自体を植物種ごとの
// マスタデータ(例: species_thresholdsテーブル)に置き換える前提。
// そのときにこの関数群のシグネチャ(month, thresholdsを渡す形)を大きく
// 変えずに済むよう、閾値を1箇所(MONSTERA_SEASONAL_SOIL_THRESHOLDS)に
// まとめてある。
const MONSTERA_SEASONAL_SOIL_THRESHOLDS = {
  // 夏(6〜9月): 蒸散が多く乾きやすいため、他の季節より高めの閾値。
  summer: { healthy: 40, needsCare: 20 }, // 注意ゾーン: 20% <= soil < 40%
  // 冬(12〜2月): 休眠期で水やり頻度を落とすため、低めの閾値。
  winter: { healthy: 30, needsCare: 15 }, // 注意ゾーン: 15% <= soil < 30%
  // 春・秋(上記以外の月): 夏と冬の中間的な閾値。
  default: { healthy: 35, needsCare: 18 }, // 注意ゾーン: 18% <= soil < 35%
};

const SUMMER_MONTHS = [6, 7, 8, 9];
const WINTER_MONTHS = [12, 1, 2];

function getSoilSeasonForMonth(month) {
  if (SUMMER_MONTHS.includes(month)) return 'summer';
  if (WINTER_MONTHS.includes(month)) return 'winter';
  return 'default';
}

/** 指定した月(1〜12)の季節別閾値を返す。 */
export function getSeasonalSoilThresholds(month) {
  return MONSTERA_SEASONAL_SOIL_THRESHOLDS[getSoilSeasonForMonth(month)];
}

/**
 * 土壌水分の現在値が、指定した月の季節別閾値でどのゾーンにあるかを判定する。
 *   healthy         : 季節別のhealthy閾値以上
 *   caution_zone    : healthy未満〜needsCare以上(継続時間で healthy→thirsty に格上げ)
 *   needs_care_zone : 季節別のneedsCare閾値未満(水やり緩和が無ければ即座にdry)
 */
export function classifySoilZone(soil, month) {
  const { healthy, needsCare } = getSeasonalSoilThresholds(month);
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
 *   (温度(resolveTemperatureStatus)と同じ「バッジ自体を継続時間で遅らせる」方式。
 *   通知だけを遅らせるサイレントタイムとは別の考え方だが、これは一時的なブレで
 *   一喜一憂させないという季節別閾値の意図そのものであるため。)
 * - needs_care_zone: 原則即座に'dry'。ただし前回の水やりから2時間以内なら、
 *   センサーの応答遅れ・水が浸透しきっていないだけの可能性が高いため
 *   'thirsty'に緩和する(注意ゾーンには緩和を適用しない。継続時間による
 *   6時間の猶予が既にあるため)。
 *
 * @param {object} params
 * @param {number} params.soil 現在の土壌水分(%)
 * @param {number} params.month 現在の月(1〜12、JST基準。utils/time.jsのgetMonthInJst参照)
 * @param {string|null} params.previousCautionSince 前回caution_zoneに入り続けている開始時刻(ISO8601)
 * @param {Date} params.now 現在時刻
 * @param {string|null} params.lastWateredAt 直近の水やり記録時刻(ISO8601、docs 4-2章)。未記録ならnull。
 * @returns {{ status: 'healthy'|'thirsty'|'dry', cautionSince: Date|null }}
 */
export function resolveSoilStatus({ soil, month, previousCautionSince, now, lastWateredAt }) {
  const zone = classifySoilZone(soil, month);

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
 *   healthy      : 18〜30℃(適正)
 *   caution_zone : 上記の外側だが危険域ではない(継続時間で healthy→caution→needs_care と格上げ)
 *   danger       : 10℃未満 または 35℃以上(継続時間を問わず即座にneeds_care)
 *
 * 元のdocs記載では「10〜15℃」がcaution_zoneにもdangerにも該当しない
 * 抜け穴になっていたため、caution_zoneの下限を15℃ではなく10℃に広げて
 * 埋めている(この関数を実装する過程で発見・修正)。
 */
export function classifyTemperatureZone(temperature) {
  if (temperature < 10 || temperature >= 35) return 'danger';
  if (temperature < 18 || temperature > 30) return 'caution_zone';
  return 'healthy';
}

/**
 * 温度の継続時間を考慮した最終的なステータスを算出する(docs 3-1)。
 *
 * @param {number} temperature 現在の温度
 * @param {string|null} previousSince 前回このゾーンに入った時刻(ISO8601)。
 *   healthy状態からcaution_zoneに入った瞬間はnullを渡す想定。
 * @param {Date} now 現在時刻(テスト容易性のため引数で受け取る)
 * @returns {{ status: 'healthy'|'caution'|'needs_care', since: Date|null }}
 *   since: caution_zoneに入り続けている開始時刻。healthy/dangerに至った場合はnull
 *   (healthyはリセット、dangerは継続時間を問わないため管理不要)。
 */
export function resolveTemperatureStatus(temperature, previousSince, now = new Date()) {
  const zone = classifyTemperatureZone(temperature);

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
 *   healthy    : 60〜80%
 *   caution    : 40〜60% または 80〜90%
 *   needs_care : 40%未満 または 90%超
 *
 * 90%超をneeds_careに含めているのは、元のdocs記載(「40%未満などが長時間継続」)
 * には上限側の要ケア条件が明記されていなかったため、多湿による根腐れ・カビ
 * リスクを考慮しこの関数の実装時に補った判断。要すり合わせ。
 */
export function classifyHumidityDailyAverage(averageHumidity) {
  if (averageHumidity < 40 || averageHumidity > 90) return 'needs_care';
  if (averageHumidity < 60 || averageHumidity > 80) return 'caution';
  return 'healthy';
}

/**
 * 照度の「昼間(6:00〜18:00)平均」から日次ステータスを判定する(docs 3-4)。
 *   healthy    : 1,000〜10,000 lux
 *   caution    : 500〜1,000 lux
 *   needs_care : 500 lux未満
 *
 * 上限側(直射日光が強すぎるケース)は docs 3-4 のTODO通り今回は未対応。
 */
export function classifyIlluminanceDailyAverage(averageIlluminance) {
  if (averageIlluminance < 500) return 'needs_care';
  if (averageIlluminance < 1000) return 'caution';
  return 'healthy';
}
