import db from '../database/db.js';
import { sendError } from '../utils/errors.js';
import { parseHourMinute } from '../utils/time.js';

// notification_settingsはアプリ全体で1レコードのみ運用する(設計書6章ER図の注記)。
const selectSettingsStmt = db.prepare(`SELECT * FROM notification_settings WHERE id = 1`);

const updateSettingsStmt = db.prepare(`
  UPDATE notification_settings
  SET
    start_time = ?,
    end_time = ?,
    sound_enabled = ?,
    soil_alert_enabled = ?,
    temperature_alert_enabled = ?,
    humidity_alert_enabled = ?,
    illuminance_alert_enabled = ?
  WHERE id = 1
`);

function toBooleanFlag(value) {
  return value ? 1 : 0;
}

function toResponse(row) {
  return {
    start_time: row.start_time,
    end_time: row.end_time,
    sound_enabled: Boolean(row.sound_enabled),
    soil_alert_enabled: Boolean(row.soil_alert_enabled),
    temperature_alert_enabled: Boolean(row.temperature_alert_enabled),
    humidity_alert_enabled: Boolean(row.humidity_alert_enabled),
    illuminance_alert_enabled: Boolean(row.illuminance_alert_enabled),
    // バッテリーアラートは今回のスコープ外(ESP32側にバッテリー残量の送信
    // 機能自体がまだ無いため)。フィールド自体を返さないことで、
    // Flutter側がうっかり「保存されている設定」だと誤解しないようにしている。
  };
}

// GET /settings/notification (設計書5-1)
export function getNotificationSettings(req, res) {
  const row = selectSettingsStmt.get();
  res.json(toResponse(row));
}

// PUT /settings/notification (設計書5-1)
//
// frequencyは現状どの画面からも編集されておらず(設定画面のトグルは
// 種別ごとのON/OFFとサイレントタイムのみ)、値も定義し切れていないため、
// このAPIでは更新対象に含めていない(将来「通知頻度」の選択肢が固まった
// 時点で追加する)。
export function updateNotificationSettings(req, res) {
  const current = selectSettingsStmt.get();
  const body = req.body ?? {};

  const startTime = body.start_time ?? current.start_time;
  const endTime = body.end_time ?? current.end_time;

  if (!parseHourMinute(startTime) || !parseHourMinute(endTime)) {
    return sendError(
      res,
      400,
      'VALIDATION_ERROR',
      'start_time・end_timeは"HH:MM"形式(0埋め、例: "20:00")で指定してください',
    );
  }

  const soundEnabled =
    body.sound_enabled !== undefined ? toBooleanFlag(body.sound_enabled) : current.sound_enabled;
  const soilAlertEnabled =
    body.soil_alert_enabled !== undefined
      ? toBooleanFlag(body.soil_alert_enabled)
      : current.soil_alert_enabled;
  const temperatureAlertEnabled =
    body.temperature_alert_enabled !== undefined
      ? toBooleanFlag(body.temperature_alert_enabled)
      : current.temperature_alert_enabled;
  const humidityAlertEnabled =
    body.humidity_alert_enabled !== undefined
      ? toBooleanFlag(body.humidity_alert_enabled)
      : current.humidity_alert_enabled;
  const illuminanceAlertEnabled =
    body.illuminance_alert_enabled !== undefined
      ? toBooleanFlag(body.illuminance_alert_enabled)
      : current.illuminance_alert_enabled;

  updateSettingsStmt.run(
    startTime,
    endTime,
    soundEnabled,
    soilAlertEnabled,
    temperatureAlertEnabled,
    humidityAlertEnabled,
    illuminanceAlertEnabled,
  );

  res.json(toResponse(selectSettingsStmt.get()));
}
