/**
 * POST /sensor 用のバリデーション(設計書5-4)。
 *
 * ESP32連携が始まると、想定外の値(文字列化された数値、NaN、負数、
 * 欠損値など)が届く可能性があるため、保存前に型とレンジを確認する。
 * 閾値判定(healthy/thirsty/dry)自体はutils/plantStatus.jsが担当し、
 * ここでは「保存してよい値かどうか」のみをチェックする。
 *
 * 戻り値: 問題なければnull、問題があればユーザー向けエラーメッセージ(string)。
 *
 * デバイスペアリング機能の実装に伴い、plant_idではなくdevice_idを受け取る
 * 設計書5-4本来の形に戻した(元のplant_id直接指定版は5-4の<details>を参照)。
 */
export function validateSensorPayload({ device_id, temperature, humidity, soil, illuminance }) {
  if (!isPositiveInteger(device_id)) {
    return 'device_id は正の整数で指定してください';
  }

  // soilは状態判定(5-7)に直結するため必須・レンジ検証ともに厳密にする。
  if (soil === undefined || !isNumberInRange(soil, 0, 100)) {
    return 'soil は0〜100の数値で指定してください';
  }

  // temperature/humidity/illuminanceは任意項目のため、指定された場合のみ検証する。
  if (temperature !== undefined && !isNumberInRange(temperature, -20, 60)) {
    return 'temperature は-20〜60の数値で指定してください';
  }
  if (humidity !== undefined && !isNumberInRange(humidity, 0, 100)) {
    return 'humidity は0〜100の数値で指定してください';
  }
  if (illuminance !== undefined && !isNumberInRange(illuminance, 0, Infinity)) {
    return 'illuminance は0以上の数値で指定してください';
  }

  return null;
}

/**
 * POST /devices/pair 用のバリデーション(設計書5-3)。
 *
 * device_name: 空でない文字列(必須)
 * mac_address: "AA:BB:CC:DD:EE:FF"形式の文字列(必須)
 *
 * 戻り値: 問題なければnull、問題があればユーザー向けエラーメッセージ(string)。
 */
export function validateDevicePairPayload({ device_name, mac_address }) {
  if (typeof device_name !== 'string' || device_name.trim() === '') {
    return 'device_name は空でない文字列で指定してください';
  }
  if (typeof mac_address !== 'string' || !isMacAddress(mac_address)) {
    return 'mac_address は "AA:BB:CC:DD:EE:FF" 形式の文字列で指定してください';
  }
  return null;
}

/**
 * PUT/DELETE /devices/tokens 用のバリデーション(docs/push-notification-design.md 4章)。
 *
 * fcm_token: 空でない文字列(必須)
 * platform: 'android' | 'ios'(省略時は'android'。Android先行のため。docs 1章参照)
 *
 * 戻り値: 問題なければnull、問題があればユーザー向けエラーメッセージ(string)。
 */
export function validateDeviceTokenPayload({ fcm_token, platform }) {
  if (typeof fcm_token !== 'string' || fcm_token.trim() === '') {
    return 'fcm_token は空でない文字列で指定してください';
  }
  if (platform !== undefined && platform !== 'android' && platform !== 'ios') {
    return "platform は 'android' または 'ios' で指定してください";
  }
  return null;
}

function isMacAddress(value) {
  return /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/.test(value);
}

function isPositiveInteger(value) {
  // 元のコードが selectPlantStmt.get(Number(plant_id)) と数値へ変換していた
  // ことに合わせ、数値そのものだけでなく数値文字列("1"など)も許容する。
  // ただし空文字・小数・NaNは弾く。
  if (typeof value !== 'number' && typeof value !== 'string') return false;
  const n = Number(value);
  return Number.isInteger(n) && n > 0 && String(value).trim() !== '';
}

function isNumberInRange(value, min, max) {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}
