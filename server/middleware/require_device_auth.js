import { timingSafeEqual } from 'node:crypto';
import { sendError } from '../utils/errors.js';

export function requireDeviceAuth(req, res, next) {
  const configuredKey = process.env.DEVICE_API_KEY;
  const requestKey = req.headers['x-device-api-key'];

  if (!configuredKey || typeof requestKey !== 'string') {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証が必要です');
  }

  const expected = Buffer.from(configuredKey);
  const actual = Buffer.from(requestKey);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'デバイス認証に失敗しました');
  }

  return next();
}