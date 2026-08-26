import { getAuth } from 'firebase-admin/auth';
import { sendError } from '../utils/errors.js';

export async function requireAuth(req, res, next) {
  const authorization = req.headers.authorization ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return sendError(res, 401, 'UNAUTHENTICATED', 'ログインが必要です');
  }

  try {
    req.user = await getAuth().verifyIdToken(token);
    return next();
  } catch (error) {
    console.warn('Firebase IDトークンの検証に失敗しました:', error.message);
    return sendError(res, 401, 'UNAUTHENTICATED', '認証トークンが無効です');
  }
}