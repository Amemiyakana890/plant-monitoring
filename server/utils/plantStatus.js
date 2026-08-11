/**
 * 土壌水分値から植物の状態(status)を判定する(設計書5-7)。
 *   healthy(元気です)   : soil >= 40
 *   thirsty(少し乾いています) : 20 <= soil < 40
 *   dry(乾燥しています)  : soil < 20
 *
 * 閾値は将来的に植物種ごとに変える可能性があるため(設計書5-7の注記)、
 * ここに集約しておき、変更が必要になったらこの関数だけ直せばよいようにしている。
 */
export function determineStatus(soil) {
  if (soil >= 40) return 'healthy';
  if (soil >= 20) return 'thirsty';
  return 'dry';
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
