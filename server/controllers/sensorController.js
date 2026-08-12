import db from '../database/db.js';
import {
  determineStatus,
  resolveTemperatureStatus,
  classifyHumidityDailyAverage,
  classifyIlluminanceDailyAverage,
} from '../utils/plantStatus.js';
import { validateSensorPayload } from '../utils/validation.js';
import { sendError } from '../utils/errors.js';
import {
  toSqliteTimestamp,
  shouldRunDailyEvaluation,
  hasPassedDailyMarker,
  isWithinSilentTime,
  parseHourMinute,
} from '../utils/time.js';

// device_idから紐づく植物を1件引く(設計書6章: plants.device_id → devices.id)。
// 設計書5-4本文の「devices.plant_id を参照」という記述は、実際のテーブル定義
// (6章)とは逆向きの記載だったための表記ゆれ。実装は6章のスキーマに合わせる。
const selectPlantByDeviceIdStmt = db.prepare(
  `SELECT * FROM plants WHERE device_id = ?`,
);

const selectNotificationSettingsStmt = db.prepare(
  `SELECT * FROM notification_settings WHERE id = 1`,
);

const insertLogStmt = db.prepare(
  `INSERT INTO sensor_logs (plant_id, temperature, humidity, soil, illuminance)
   VALUES (?, ?, ?, ?, ?)`,
);

const updateStatusStmt = db.prepare(
  `UPDATE plants SET status = ? WHERE id = ?`,
);

const updateTemperatureStmt = db.prepare(
  `UPDATE plants SET temp_status = ?, temp_out_of_range_since = ? WHERE id = ?`,
);

const updateHumidityDailyStmt = db.prepare(
  `UPDATE plants SET humidity_daily_status = ?, humidity_daily_avg = ?, humidity_evaluated_at = ? WHERE id = ?`,
);

const updateIlluminanceDailyStmt = db.prepare(
  `UPDATE plants SET illuminance_daily_status = ?, illuminance_daily_avg = ?, illuminance_evaluated_at = ? WHERE id = ?`,
);

const setPendingNotificationStmt = db.prepare(
  `UPDATE plants SET pending_notification = ? WHERE id = ?`,
);

const setSilentTimeUnlockCheckedAtStmt = db.prepare(
  `UPDATE plants SET silent_time_unlock_checked_at = ? WHERE id = ?`,
);

// 湿度: 直近24時間の単純平均(docs/status-notification-design.md 3-2)。
const selectHumidityDailyAverageStmt = db.prepare(`
  SELECT AVG(humidity) AS avg_value, COUNT(*) AS sample_count
  FROM sensor_logs
  WHERE plant_id = ?
    AND humidity IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
`);

// 照度: 直近24時間のうち「昼間(6:00〜18:00, JST)」だけを抽出して平均する
// (docs/status-notification-design.md 3-4)。
// created_atはUTCで保存されているため(database/db.js参照)、+9時間して
// JSTに補正してから時刻部分を取り出す。日本国内・DST無しを前提に固定オフセット
// としている(将来海外展開する場合は要見直し)。
const selectIlluminanceDaytimeAverageStmt = db.prepare(`
  SELECT AVG(illuminance) AS avg_value, COUNT(*) AS sample_count
  FROM sensor_logs
  WHERE plant_id = ?
    AND illuminance IS NOT NULL
    AND created_at >= datetime('now', '-24 hours')
    AND CAST(strftime('%H', created_at, '+9 hours') AS INTEGER) >= 6
    AND CAST(strftime('%H', created_at, '+9 hours') AS INTEGER) < 18
`);

// categoryは 'soil' / 'temperature' / 'humidity' / 'illuminance' のいずれか
// (database/db.jsのマイグレーション参照)。
// もともとFlutter側は通知メッセージの文言に含まれるキーワードでアイコンを
// 推測していたが、土壌水分の「やや乾燥」メッセージには「水分」という文字列が
// 含まれておらず汎用アイコンになってしまうバグがあった。文言に依存しない
// 判定にするため、生成する側であるここで明示的なカテゴリを持たせている。
const insertNotificationStmt = db.prepare(
  `INSERT INTO notifications (plant_id, message, category) VALUES (?, ?, ?)`,
);

// 状態が「悪化した」場合にのみ通知するための順位付け(設計書5-7・F-05)。
// 「静かに見守る」コンセプト上、同じ状態が続く間は毎回通知しない。
// 温度も同じ3段階(healthy/caution/needs_care)の悪化判定を使う
// (docs/status-notification-design.md 6-1〜6-3)。
const SOIL_STATUS_RANK = { healthy: 0, thirsty: 1, dry: 2 };
const LEVEL_RANK = { healthy: 0, caution: 1, needs_care: 2 };

const SOIL_NOTIFICATION_MESSAGE = {
  thirsty: '少し乾いてきました。水やりのタイミングを確認してください',
  dry: '土壌水分が少なくなっています。水やりが必要です',
};

const TEMPERATURE_NOTIFICATION_MESSAGE = {
  caution: '気温が適正範囲(18〜30℃)から外れた状態が30分以上続いています。置き場所を確認してください',
  needs_care: '気温が大きく外れています。植物の置き場所をすぐに見直してください',
};

// 湿度・照度の通知メッセージは平均値を埋め込むため、日次評価(runDailyEvaluations)と
// サイレントタイム解禁時の再通知(buildWorstAxisMessage)の両方から呼べるよう
// 関数として切り出している。
function buildHumidityNeedsCareMessage(avgHumidity) {
  return avgHumidity < 40
    ? `過去24時間の湿度が低めです(平均${avgHumidity.toFixed(0)}%)。乾燥に注意してください`
    : `過去24時間の湿度が高めです(平均${avgHumidity.toFixed(0)}%)。蒸れ・カビに注意してください`;
}

function buildIlluminanceNeedsCareMessage(avgIlluminance) {
  return `過去24時間(昼間)の日照が不足しています(平均${avgIlluminance.toFixed(0)}lux)。日当たりの良い場所への移動を検討してください`;
}

// サイレントタイム中(docs 6-4章)は通知を直接作らず、「悪化があった」という
// フラグだけを立てる。解禁時にその時点の最新の状態から通知を作り直すため、
// メッセージの中身はここでは保持しない。
//
// NOTE: トグルOFF(通知アラート無効)のカテゴリは、この関数を呼ぶ「前」の
// 各maybeCreate*/runDailyEvaluations側でガードして呼ばないようにしている
// (=OFFのカテゴリはpending_notificationも一切立てない。判定・表示自体は
// 止めない設計なので、plants側のステータス更新は常に行う点に注意)。
function notifyOrDefer(plant, message, category, silentNow) {
  if (silentNow) {
    setPendingNotificationStmt.run(1, plant.id);
    return;
  }
  insertNotificationStmt.run(plant.id, message, category);
}

// 土壌水分の状態がpreviousStatusからnewStatusへ悪化した場合のみ通知を1件作成する。
// (healthy→thirsty、thirsty→dry、healthy→dryのいずれか。改善方向は通知しない)
// トグルOFF時は判定(plants.statusの更新)は行うが通知だけ止める。
function maybeCreateSoilNotification(plant, previousStatus, newStatus, silentNow, enabled) {
  if (!enabled) return;

  const previousRank = SOIL_STATUS_RANK[previousStatus] ?? 0;
  const newRank = SOIL_STATUS_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return;

  const message = SOIL_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return;

  notifyOrDefer(plant, message, 'soil', silentNow);
}

// 温度の状態がpreviousStatusからnewStatusへ悪化した場合のみ通知を1件作成する
// (docs/status-notification-design.md 6-1: リアルタイム系は「悪化した瞬間のみ」通知)。
function maybeCreateTemperatureNotification(plant, previousStatus, newStatus, silentNow, enabled) {
  if (!enabled) return;

  const previousRank = LEVEL_RANK[previousStatus] ?? 0;
  const newRank = LEVEL_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return;

  const message = TEMPERATURE_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return;

  notifyOrDefer(plant, message, 'temperature', silentNow);
}

// 湿度・照度の日次レポート(docs 6-5)を評価し、DBを更新する。
// 6-5の最終確定ルール:「その日の評価が要ケアの場合のみ通知する」
// (前回の評価と比較しない。要ケアが続く限り毎日15:00に通知する)。
// トグルOFF時も評価・DB更新自体は行い、通知の生成だけをスキップする
// (ホーム画面のバッジ表示は変わらず動く)。
//
// @returns {{ humidityDailyStatus: string|null, illuminanceDailyStatus: string|null }}
//   このtick終了時点での最新のステータス(評価しなかった場合はplantの既存値をそのまま返す)。
//   サイレントタイム中の「全項目が適正に戻ったか」判定(isFullyHealthy)で使う。
function runDailyEvaluations(plant, now, silentNow, settings) {
  let humidityDailyStatus = plant.humidity_daily_status;
  let illuminanceDailyStatus = plant.illuminance_daily_status;

  if (shouldRunDailyEvaluation(plant.humidity_evaluated_at, now)) {
    const { avg_value: avgHumidity, sample_count: sampleCount } =
      selectHumidityDailyAverageStmt.get(plant.id);

    // 直近24時間に湿度データが1件もない場合はAVGがnullになる。
    // 評価不能なのでevaluated_atも更新せず、次回受信時に再試行する。
    if (avgHumidity !== null && sampleCount > 0) {
      humidityDailyStatus = classifyHumidityDailyAverage(avgHumidity);
      updateHumidityDailyStmt.run(
        humidityDailyStatus,
        avgHumidity,
        toSqliteTimestamp(now),
        plant.id,
      );

      if (humidityDailyStatus === 'needs_care' && settings.humidity_alert_enabled) {
        notifyOrDefer(plant, buildHumidityNeedsCareMessage(avgHumidity), 'humidity', silentNow);
      }
    }
  }

  if (shouldRunDailyEvaluation(plant.illuminance_evaluated_at, now)) {
    const { avg_value: avgIlluminance, sample_count: sampleCount } =
      selectIlluminanceDaytimeAverageStmt.get(plant.id);

    if (avgIlluminance !== null && sampleCount > 0) {
      illuminanceDailyStatus = classifyIlluminanceDailyAverage(avgIlluminance);
      updateIlluminanceDailyStmt.run(
        illuminanceDailyStatus,
        avgIlluminance,
        toSqliteTimestamp(now),
        plant.id,
      );

      if (illuminanceDailyStatus === 'needs_care' && settings.illuminance_alert_enabled) {
        notifyOrDefer(
          plant,
          buildIlluminanceNeedsCareMessage(avgIlluminance),
          'illuminance',
          silentNow,
        );
      }
    }
  }

  return { humidityDailyStatus, illuminanceDailyStatus };
}

// 4項目(土壌水分・温度・湿度・照度)のうち最も深刻なものの通知内容を返す。
// サイレントタイム解禁時(docs 6-4章)に「その時点の最新の状態」から通知を
// 作り直すために使う。healthy(=通知不要)しかない場合、または該当項目の
// アラートがすべてOFFの場合はnullを返す。
//
// トグルOFFのカテゴリを候補から除外することで、「湿度アラートをOFFにしている
// のに、サイレントタイム解禁時には湿度の内容で通知が来る」という矛盾を防ぐ。
function buildWorstAxisNotification(plant, settings) {
  const candidates = [
    {
      rank: settings.soil_alert_enabled ? SOIL_STATUS_RANK[plant.status] ?? 0 : 0,
      message: SOIL_NOTIFICATION_MESSAGE[plant.status],
      category: 'soil',
    },
    {
      rank: settings.temperature_alert_enabled ? LEVEL_RANK[plant.temp_status] ?? 0 : 0,
      message: TEMPERATURE_NOTIFICATION_MESSAGE[plant.temp_status],
      category: 'temperature',
    },
    {
      rank: settings.humidity_alert_enabled ? LEVEL_RANK[plant.humidity_daily_status] ?? 0 : 0,
      message:
        plant.humidity_daily_avg !== null && plant.humidity_daily_avg !== undefined
          ? buildHumidityNeedsCareMessage(plant.humidity_daily_avg)
          : undefined,
      category: 'humidity',
    },
    {
      rank: settings.illuminance_alert_enabled
        ? LEVEL_RANK[plant.illuminance_daily_status] ?? 0
        : 0,
      message:
        plant.illuminance_daily_avg !== null && plant.illuminance_daily_avg !== undefined
          ? buildIlluminanceNeedsCareMessage(plant.illuminance_daily_avg)
          : undefined,
      category: 'illuminance',
    },
  ].filter((candidate) => candidate.rank > 0 && candidate.message);

  if (candidates.length === 0) return null;

  candidates.sort((a, b) => b.rank - a.rank);
  const winner = candidates[0];
  return { message: winner.message, category: winner.category };
}

// サイレントタイム解禁チェック(docs 6-4章)。
// 「サイレントタイムが終わった後、最初にセンサーを受信したタイミングで、
//  その時点の最新の状態を元に通知を1件だけ生成する」というA案を実装したもの。
// pending_notification(悪化があったかどうかのフラグ)を見て、
//   - 1(悪化があった) → その時点の最新の状態から通知を1件作る
//   - 0(悪化がなかった、または夜間に回復した) → 何もせず、チェック済みの記録だけ残す
// 1日1回しか実行しないよう、silent_time_unlock_checked_atをマーカーとして使う
// (5章の日次評価と同じ設計パターン。utils/time.js参照)。
//
// NOTE: この関数はセンサー受信処理の「更新前」の状態(plant)を見て判定する。
// 「夜間に何が起きていたか」を反映するのが目的のため、今回の受信で新しく届いた
// 値ではなく、直前まで保持していた状態を使うのが自然という判断。
function runSilentTimeUnlockCheck(plant, now, settings, silentNow) {
  if (silentNow) return; // サイレントタイム中は解禁チェック自体を行わない

  const end = parseHourMinute(settings.end_time) ?? { hour: 6, minute: 0 };
  const shouldCheck = hasPassedDailyMarker(
    plant.silent_time_unlock_checked_at,
    now,
    end.hour,
    end.minute,
  );
  if (!shouldCheck) return;

  if (plant.pending_notification) {
    const notification = buildWorstAxisNotification(plant, settings);
    if (notification) {
      insertNotificationStmt.run(plant.id, notification.message, notification.category);
    }
    setPendingNotificationStmt.run(0, plant.id);
  }

  setSilentTimeUnlockCheckedAtStmt.run(toSqliteTimestamp(now), plant.id);
}

// 4項目すべてが適正(healthy)に戻っているかを判定する。
// サイレントタイム中に問題が解消した場合、pending_notificationをクリアするために使う
// (docs 6-4章:「サイレントタイム中に状態が回復した場合は、pending_notificationを
// クリアする」)。湿度・照度は1日1回しか評価されないため、直近の日次評価結果を
// そのまま使う(このtickで新たに再評価されるとは限らない点に注意)。
function isFullyHealthy({ soilStatus, tempStatus, humidityDailyStatus, illuminanceDailyStatus }) {
  return (
    (SOIL_STATUS_RANK[soilStatus] ?? 0) === 0 &&
    (LEVEL_RANK[tempStatus] ?? 0) === 0 &&
    (LEVEL_RANK[humidityDailyStatus] ?? 0) === 0 &&
    (LEVEL_RANK[illuminanceDailyStatus] ?? 0) === 0
  );
}

// POST /sensor (設計書5-4)
//
// デバイスペアリング機能の実装に伴い、plant_idを直接受け取る簡易版から
// device_id起点の本来設計に戻した。ESP32はdevice_idを送り、サーバー側で
// plants.device_idを参照してどの植物のログかを判定する。
export function receiveSensorData(req, res) {
  const { device_id, temperature, humidity, soil, illuminance } =
    req.body ?? {};

  const validationError = validateSensorPayload({
    device_id,
    temperature,
    humidity,
    soil,
    illuminance,
  });
  if (validationError) {
    return sendError(res, 400, 'VALIDATION_ERROR', validationError);
  }

  const plant = selectPlantByDeviceIdStmt.get(Number(device_id));
  if (!plant) {
    // デバイス自体は登録済みだが、どの植物にも紐付けられていない
    // (POST /plants または PATCH /plants/:id でdevice_idを設定していない)場合もここに来る。
    return sendError(
      res,
      404,
      'PLANT_NOT_FOUND',
      '指定されたデバイスに紐付く植物が見つかりません。先にPOST /plantsまたはPATCH /plants/:idでdevice_idを設定してください',
    );
  }

  const now = new Date();
  const settings = selectNotificationSettingsStmt.get();
  const silentNow = isWithinSilentTime(now, settings.start_time, settings.end_time);

  // サイレントタイムの解禁チェックは、今回の受信で値を更新する「前」の
  // plantの状態(=夜間の間ずっと保持されていた最新の状態)を見て行う。
  runSilentTimeUnlockCheck(plant, now, settings, silentNow);

  insertLogStmt.run(
    plant.id,
    temperature ?? null,
    humidity ?? null,
    soil,
    illuminance ?? null,
  );

  // 土壌水分: 受信のたびに閾値と比較して plants.status を更新する(設計書5-4・5-7)。
  // NOTE: plants.statusは現時点でも土壌水分専用のまま変更していない
  // (healthy/thirsty/dryという語彙自体が「水やり」を意味しており、
  // 温度・湿度・照度の悪化をここに混ぜるとホーム画面の元のメッセージ
  // (例:「乾燥しています」)と実態が食い違う可能性があるため。
  // 4項目のworst-ofをホーム画面にどう出すかはFlutter側の対応と合わせて
  // 別途検討する。docs/status-notification-design.md 3-5章を参照)。
  //
  // トグルOFF時もこのstatus自体の更新は行う(通知だけを止める設計。
  // 前回の会話での確認事項)。
  const previousSoilStatus = plant.status;
  const soilStatus = determineStatus(soil);
  updateStatusStmt.run(soilStatus, plant.id);
  maybeCreateSoilNotification(
    plant,
    previousSoilStatus,
    soilStatus,
    silentNow,
    Boolean(settings.soil_alert_enabled),
  );

  // 温度: リアルタイム・継続時間ベース(docs 3-1)。temperatureが未送信の場合はスキップ。
  let tempStatus = plant.temp_status ?? 'healthy';
  if (temperature !== undefined && temperature !== null) {
    const previousTempStatus = plant.temp_status ?? 'healthy';
    const resolved = resolveTemperatureStatus(
      temperature,
      plant.temp_out_of_range_since,
      now,
    );
    tempStatus = resolved.status;
    updateTemperatureStmt.run(
      tempStatus,
      resolved.since ? toSqliteTimestamp(resolved.since) : null,
      plant.id,
    );
    maybeCreateTemperatureNotification(
      plant,
      previousTempStatus,
      tempStatus,
      silentNow,
      Boolean(settings.temperature_alert_enabled),
    );
  }

  // 湿度・照度: 1日1回、15:00をまたいだ最初の受信で評価する(docs 5章・6-5章)。
  const { humidityDailyStatus, illuminanceDailyStatus } = runDailyEvaluations(
    plant,
    now,
    silentNow,
    settings,
  );

  // サイレントタイム中に全項目が適正へ回復していたら、pending_notificationを
  // クリアする(docs 6-4章)。湿度・照度はこのtickで再評価されるとは限らないため、
  // runDailyEvaluationsが返す「このtick終了時点での最新ステータス」を使う。
  if (silentNow) {
    const fullyHealthy = isFullyHealthy({
      soilStatus,
      tempStatus,
      humidityDailyStatus,
      illuminanceDailyStatus,
    });
    if (fullyHealthy) {
      setPendingNotificationStmt.run(0, plant.id);
    }
  }

  res.status(201).json({ plant_id: plant.id, status: soilStatus });
}
