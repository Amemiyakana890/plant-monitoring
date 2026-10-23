import { createHash, timingSafeEqual } from 'node:crypto';
import db from '../database/db.js';
import { sendError } from '../utils/errors.js';

const selectDeviceStmt = db.prepare(
  `SELECT id, owner_uid, api_key_hash FROM devices WHERE id = ?`,
);

export function requireDeviceAuth(req, res, next) {
  const requestKey = req.headers['x-device-api-key'];
  const deviceId = Number(req.body?.device_id);

  if (
    typeof requestKey !== 'string' ||
    !Number.isSafeInteger(deviceId) ||
    deviceId <= 0
  ) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証が必要です');
  }

  const device = selectDeviceStmt.get(deviceId);
  const actualHash = createHash('sha256').update(requestKey).digest();
  const expectedHash = device?.api_key_hash
    ? Buffer.from(device.api_key_hash, 'hex')
    : Buffer.alloc(0);
  if (
    !device?.owner_uid ||
    actualHash.length !== expectedHash.length ||
    !timingSafeEqual(actualHash, expectedHash)
  ) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証に失敗しました');
  }

  req.deviceOwnerUid = device.owner_uid;
  return next();
}