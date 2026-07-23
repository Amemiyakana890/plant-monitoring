/**
 * 設計書5-8のエラーレスポンス形式に統一するためのヘルパー。
 *   { "error": { "code": "...", "message": "..." } }
 */
export function sendError(res, status, code, message) {
  res.status(status).json({ error: { code, message } });
}
