import db from '../database/db.js';
import { sendError } from '../utils/errors.js';
import { getMonthInJst } from '../utils/time.js';
import { getSeasonalSoilThresholds, getSoilSeasonForMonth } from '../utils/plantStatus.js';
import { getSpeciesThresholds, getSpeciesInfo, isValidSpeciesKey } from '../utils/speciesCatalog.js';

const insertPlantStmt = db.prepare(
  `INSERT INTO plants (name, species, image, device_id) VALUES (?, ?, ?, ?)`,
);

const selectPlantStmt = db.prepare(`SELECT * FROM plants WHERE id = ?`);
const selectAllPlantsStmt = db.prepare(`SELECT * FROM plants ORDER BY id`);
const selectDeviceStmt = db.prepare(`SELECT * FROM devices WHERE id = ?`);

const updatePlantStmt = db.prepare(
  `UPDATE plants
   SET name = COALESCE(?, name),
       species = COALESCE(?, species),
       species_key = COALESCE(?, species_key),
       device_id = COALESCE(?, device_id)
   WHERE id = ?`,
);

const deletePlantStmt = db.prepare(`DELETE FROM plants WHERE id = ?`);

// created_at は datetime('now') で秒単位までしか記録されないため、
// 短時間に連続でデータが届くと created_at だけでは順序が確定しない。
// id は AUTOINCREMENT で必ず新しい行ほど大きくなるため、id DESC で確実に最新を取る。
const selectLatestLogStmt = db.prepare(
  `SELECT * FROM sensor_logs WHERE plant_id = ? ORDER BY id DESC LIMIT 1`,
);

// 水やり記録(docs/status-notification-design.md 4-2章)。sensor_logsと同じ理由で
// id DESCを使う(同一秒に複数回記録された場合でも最新を確実に取るため)。
const selectLatestWateringLogStmt = db.prepare(
  `SELECT * FROM watering_logs WHERE plant_id = ? ORDER BY id DESC LIMIT 1`,
);
const insertWateringLogStmt = db.prepare(
  `INSERT INTO watering_logs (plant_id) VALUES (?)`,
);

const SEASON_LABELS = { summer: '夏', winter: '冬', default: '春秋' };

/**
 * 植物種(species_key)から、今この瞬間の「管理条件」を算出する
 * (植物情報ページの「この植物の管理条件」カード向け、docs 3-1〜3-4章)。
 * 季節は現在時刻(JST)から自動判定する(手動切り替えは行わない方針で確定)。
 * 「水やり目安(日数)」は一度検討したが分かりやすさの観点でしっくりこず、
 * 今回は含めないことにした。
 */
function buildCareProfile(speciesKey) {
  const thresholds = getSpeciesThresholds(speciesKey);
  const month = getMonthInJst(new Date());
  const seasonKey = getSoilSeasonForMonth(month);
  const soil = getSeasonalSoilThresholds(month, thresholds);

  return {
    season: seasonKey,
    season_label: SEASON_LABELS[seasonKey],
    soil: { healthy_min: soil.healthy, needs_care_max: soil.needsCare },
    temperature: {
      healthy_min: thresholds.temperature.healthyMin,
      healthy_max: thresholds.temperature.healthyMax,
    },
    humidity: {
      healthy_min: thresholds.humidity.healthyMin,
      healthy_max: thresholds.humidity.healthyMax,
    },
    illuminance: {
      healthy_min: thresholds.illuminance.healthyMin,
    },
  };
}

/**
 * plants テーブルの1行と、直近の sensor_logs 1件を合成して
 * 設計書5-2のレスポンス例({ id, name, ..., temperature, ..., updated_at })
 * と同じ形にする。
 * まだセンサーデータが1件も届いていない植物は temperature 等が null になる。
 */
function toPlantResponse(plantRow) {
  const latestLog = selectLatestLogStmt.get(plantRow.id);
  const latestWateringLog = selectLatestWateringLogStmt.get(plantRow.id);
  return {
    id: plantRow.id,
    name: plantRow.name,
    species: plantRow.species,
    device_id: plantRow.device_id ?? null,
    status: plantRow.status,
    temperature: latestLog?.temperature ?? null,
    humidity: latestLog?.humidity ?? null,
    soil: latestLog?.soil ?? null,
    illuminance: latestLog?.illuminance ?? null,
    updated_at: latestLog?.created_at ?? null,
    // 温度・湿度・照度の状態判定・通知ロジック(docs/status-notification-design.md)。
    temp_status: plantRow.temp_status ?? null,
    humidity_daily_status: plantRow.humidity_daily_status ?? null,
    humidity_daily_avg: plantRow.humidity_daily_avg ?? null,
    illuminance_daily_status: plantRow.illuminance_daily_status ?? null,
    illuminance_daily_avg: plantRow.illuminance_daily_avg ?? null,
    // 水やり記録(4-2章)。まだ一度も記録が無い植物はnullになる。
    last_watered_at: latestWateringLog?.watered_at ?? null,
    // 植物種選択(F-08・植物切り替え機能)。species_keyが未設定(このマイグレーション
    // 以前に作成された植物)でも、species_info/care_profileはデフォルト種
    // (モンステラ)にフォールバックして返す(getSpeciesInfo/getSpeciesThresholds参照)。
    species_key: plantRow.species_key ?? null,
    species_info: getSpeciesInfo(plantRow.species_key),
    care_profile: buildCareProfile(plantRow.species_key),
  };
}

// POST /plants/:id/waterings (docs/status-notification-design.md 4-2章)
// ホーム画面の「水やりした」ボタンから呼ぶ。v1は履歴一覧を返す必要が
// ないため、記録した上で最新のplant状態(last_watered_at込み)を返す。
export function recordWatering(req, res) {
  const id = Number(req.params.id);
  const existing = selectPlantStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  insertWateringLogStmt.run(id);
  res.status(201).json(toPlantResponse(existing));
}

// POST /plants (設計書5-2)
// device_idは任意項目(未接続でも登録可)。指定する場合は登録済みのデバイスである必要がある。
export function createPlant(req, res) {
  const { name, species, image, device_id } = req.body ?? {};

  if (!name || typeof name !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'name は必須です');
  }

  if (device_id !== undefined && device_id !== null) {
    const device = selectDeviceStmt.get(Number(device_id));
    if (!device) {
      return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
    }
  }

  const result = insertPlantStmt.run(
    name,
    species ?? null,
    image ?? null,
    device_id ?? null,
  );
  const created = selectPlantStmt.get(result.lastInsertRowid);

  res.status(201).json(toPlantResponse(created));
}

// GET /plants
export function listPlants(req, res) {
  const rows = selectAllPlantsStmt.all();
  res.json(rows.map(toPlantResponse));
}

// GET /plants/:id
export function getPlant(req, res) {
  const id = Number(req.params.id);
  const row = selectPlantStmt.get(id);

  if (!row) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  res.json(toPlantResponse(row));
}

// PATCH /plants/:id (設計書5-2)
// 編集可能なのは name / species_key / device_id。未指定のフィールドは現在の値を保持する。
// device_idはデバイスペアリング完了後にここで紐付ける想定(POST /devices/pairとは別操作)。
//
// species_key(植物種の選択、F-08・植物切り替え機能)を指定した場合、
// 表示用のspecies(植物種テキスト、例:「サトイモ科モンステラ属」)は
// カタログの値で自動的に上書きする。植物名(name、ニックネーム)は
// species_keyの指定と完全に独立しており、別途自由入力できる
// (「植物名は自由記入、植物種はシステム的に選択する」という運用のため)。
export function updatePlant(req, res) {
  const id = Number(req.params.id);
  const existing = selectPlantStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  const { name, species, species_key, device_id } = req.body ?? {};

  // JSONで明示的に`null`を送ってきた場合(未指定の意図)も「更新しない」扱いに
  // したいので、undefinedだけでなくnullも許容する(device_idの判定と揃える)。
  if (name !== undefined && name !== null && (typeof name !== 'string' || name.trim() === '')) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'name は空でない文字列で指定してください');
  }
  if (species !== undefined && species !== null && typeof species !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'species は文字列で指定してください');
  }
  if (species_key !== undefined && species_key !== null) {
    if (typeof species_key !== 'string' || !isValidSpeciesKey(species_key)) {
      return sendError(
        res,
        400,
        'VALIDATION_ERROR',
        '指定された植物種(species_key)が見つかりません',
      );
    }
  }
  if (device_id !== undefined && device_id !== null) {
    const device = selectDeviceStmt.get(Number(device_id));
    if (!device) {
      return sendError(res, 404, 'DEVICE_NOT_FOUND', '指定されたデバイスが見つかりません');
    }
  }

  // species_keyが指定された場合は、表示用のspeciesテキストをカタログの値で
  // 自動的に決める(bodyで別途species文字列が送られてきても、species_keyを優先する)。
  const resolvedSpecies =
    species_key !== undefined && species_key !== null
      ? getSpeciesInfo(species_key).scientific_name
      : (species ?? null);

  updatePlantStmt.run(
    name ?? null,
    resolvedSpecies,
    species_key ?? null,
    device_id ?? null,
    id,
  );
  const updated = selectPlantStmt.get(id);
  res.json(toPlantResponse(updated));
}

// DELETE /plants/:id (設計書5-2)
// sensor_logsの外部キーにON DELETE CASCADEを設定しているため
// (database/db.js参照)、紐づくログも一緒に削除される。
export function deletePlant(req, res) {
  const id = Number(req.params.id);
  const existing = selectPlantStmt.get(id);

  if (!existing) {
    return sendError(res, 404, 'PLANT_NOT_FOUND', '指定された植物が見つかりません');
  }

  deletePlantStmt.run(id);
  res.status(204).end();
}
