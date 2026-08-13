import db from '../database/db.js';
import {
  resolveSoilStatus,
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
  getMonthInJst,
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
  `UPDATE plants SET status = ?, soil_caution_since = ? WHERE id = ?`,
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

// 水やり緩和(docs 3-3章)用。直近の水やり記録を1件取る(4-2章のwatering_logs)。
// sensor_logsと同じ理由(同一秒内の複数記録)でid DESCを使う。
const selectLatestWateringLogStmt = db.prepare(
  `SELECT * FROM watering_logs WHERE plant_id = ? ORDER BY id DESC LIMIT 1`,
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
// サイレントタイム解禁時の再通知(buildWorstAxisNotification)の両方から呼べるよう
// 関数として切り出している。
function buildHumidityNeedsCareMessage(avgHumidity) {
  return avgHumidity < 40
    ? `過去24時間の湿度が低めです(平均${avgHumidity.toFixed(0)}%)。乾燥に注意してください`
    : `過去24時間の湿度が高めです(平均${avgHumidity.toFixed(0)}%)。蒸れ・カビに注意してください`;
}

function buildIlluminanceNeedsCareMessage(avgIlluminance) {
  return `過去24時間(昼間)の日照が不足しています(平均${avgIlluminance.toFixed(0)}lux)。日当たりの良い場所への移動を検討してください`;
}

// candidatesの中から最も深刻な(rankが最大の)ものを1件選ぶ共通ヘルパー。
// rank<=0または message が無いものは候補として扱わない
// (healthy扱い、またはアラートOFFで候補生成側がnullを返したもの)。
// docs/status-notification-design.md 6-3: 「複数項目が同時に悪化した場合、
// 通知メッセージは最も深刻な項目を優先して1件生成する」を実現するための要。
function pickWorstCandidate(candidates) {
  const valid = candidates.filter((c) => c && c.rank > 0 && c.message);
  if (valid.length === 0) return null;
  valid.sort((a, b) => b.rank - a.rank);
  return valid[0];
}

// 土壌水分の状態がpreviousStatusからnewStatusへ悪化した場合のみ、
// 通知の「候補」を返す(healthy→thirsty、thirsty→dry、healthy→dryのいずれか。
// 改善方向はnull)。実際に通知を作成するかどうかは呼び出し元
// (receiveSensorData)が他項目の候補とまとめて判断する(6-3章の1件集約)。
// トグルOFF時はそもそも候補にしない(判定=plants.statusの更新は別途行う)。
function evaluateSoilNotificationCandidate(previousStatus, newStatus, enabled) {
  if (!enabled) return null;

  const previousRank = SOIL_STATUS_RANK[previousStatus] ?? 0;
  const newRank = SOIL_STATUS_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return null;

  const message = SOIL_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return null;

  return { rank: newRank, message, category: 'soil' };
}

// 温度版。考え方はevaluateSoilNotificationCandidateと同じ
// (docs 6-1: リアルタイム系は「悪化した瞬間のみ」候補になる)。
function evaluateTemperatureNotificationCandidate(previousStatus, newStatus, enabled) {
  if (!enabled) return null;

  const previousRank = LEVEL_RANK[previousStatus] ?? 0;
  const newRank = LEVEL_RANK[newStatus] ?? 0;
  if (newRank <= previousRank) return null;

  const message = TEMPERATURE_NOTIFICATION_MESSAGE[newStatus];
  if (!message) return null;

  return { rank: newRank, message, category: 'temperature' };
}

// 湿度・照度の日次レポート(docs 6-5)を評価し、DBを更新する。
// 6-5の最終確定ルール:「その日の評価が要ケアの場合のみ通知する」
// (前回の評価と比較しない。要ケアが続く限り毎日15:00に通知する)。
// トグルOFF時も評価・DB更新自体は行い、通知候補の生成だけをスキップする
// (ホーム画面のバッジ表示は変わらず動く)。
//
// @returns {{
//   humidityDailyStatus: string|null,
//   illuminanceDailyStatus: string|null,
//   candidates: Array<{rank:number, message:string, category:string}>
// }}
//   ステータスはこのtick終了時点での最新値(評価しなかった場合はplantの
//   既存値をそのまま返す)。candidatesは呼び出し元で他項目とまとめて
//   pickWorstCandidate()にかける(6-3章の1件集約)。
function runDailyEvaluations(plant, now, settings) {
  let humidityDailyStatus = plant.humidity_daily_status;
  let illuminanceDailyStatus = plant.illuminance_daily_status;
  const candidates = [];

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
        candidates.push({
          rank: LEVEL_RANK.needs_care,
          message: buildHumidityNeedsCareMessage(avgHumidity),
          category: 'humidity',
        });
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
        candidates.push({
          rank: LEVEL_RANK.needs_care,
          message: buildIlluminanceNeedsCareMessage(avgIlluminance),
          category: 'illuminance',
        });
      }
    }
  }

  return { humidityDailyStatus, illuminanceDailyStatus, candidates };
}

// 4項目(土壌水分・温度・湿度・照度)のうち最も深刻なものの通知内容を返す。
// サイレントタイム解禁時(docs 6-4章)に「その時点の最新の状態」から通知を
// 作り直すために使う。healthy(=通知不要)しかない場合、または該当項目の
// アラートがすべてOFFの場合はnullを返す。
//
// トグルOFFのカテゴリを候補から除外することで、「湿度アラートをOFFにしている
// のに、サイレントタイム解禁時には湿度の内容で通知が来る」という矛盾を防ぐ。
//
// NOTE: これは「その時点で現在バッドな状態にあるかどうか」を見る関数で、
// 下のreceiveSensorData内で使う「このtickで悪化"した瞬間"かどうか」を見る
// evaluate*NotificationCandidate系とは判定対象が異なる(共通なのは
// pickWorstCandidate()による1件選定のロジックのみ)。
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
  ];

  const winner = pickWorstCandidate(candidates);
  if (!winner) return null;
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

  // 土壌水分: 季節別閾値・継続時間・水やり緩和を考慮して判定する(docs 3-3章)。
  // 温度(resolveTemperatureStatus)と同じく「バッジ自体を継続時間で遅らせる」
  // 方式に統一している(一時的なブレで一喜一憂させないという3-3章の意図を、
  // 通知だけでなくバッジ表示にも反映するため)。
  //
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
  const latestWateringLog = selectLatestWateringLogStmt.get(plant.id);
  const resolvedSoil = resolveSoilStatus({
    soil,
    month: getMonthInJst(now),
    previousCautionSince: plant.soil_caution_since,
    now,
    lastWateredAt: latestWateringLog?.watered_at ?? null,
  });
  const soilStatus = resolvedSoil.status;
  updateStatusStmt.run(
    soilStatus,
    resolvedSoil.cautionSince ? toSqliteTimestamp(resolvedSoil.cautionSince) : null,
    plant.id,
  );
  const soilCandidate = evaluateSoilNotificationCandidate(
    previousSoilStatus,
    soilStatus,
    Boolean(settings.soil_alert_enabled),
  );

  // 温度: リアルタイム・継続時間ベース(docs 3-1)。temperatureが未送信の場合はスキップ。
  let tempStatus = plant.temp_status ?? 'healthy';
  let temperatureCandidate = null;
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
    temperatureCandidate = evaluateTemperatureNotificationCandidate(
      previousTempStatus,
      tempStatus,
      Boolean(settings.temperature_alert_enabled),
    );
  }

  // 湿度・照度: 1日1回、15:00をまたいだ最初の受信で評価する(docs 5章・6-5章)。
  const {
    humidityDailyStatus,
    illuminanceDailyStatus,
    candidates: dailyCandidates,
  } = runDailyEvaluations(plant, now, settings);

  // ここまでで集まった「このtickで悪化した」候補をまとめて1件に絞る
  // (docs 6-3章: 複数項目が同時に悪化しても通知は乱発しない)。
  // サイレントタイム中は中身を保持せずフラグだけ立てる(docs 6-4章、
  // 解禁時にbuildWorstAxisNotification()でその時点の最新状態から作り直す)。
  const worstCandidate = pickWorstCandidate([
    soilCandidate,
    temperatureCandidate,
    ...dailyCandidates,
  ]);
  if (worstCandidate) {
    if (silentNow) {
      setPendingNotificationStmt.run(1, plant.id);
    } else {
      insertNotificationStmt.run(plant.id, worstCandidate.message, worstCandidate.category);
    }
  }

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
