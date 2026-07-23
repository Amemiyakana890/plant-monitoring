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
