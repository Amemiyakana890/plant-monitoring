import express from 'express';

import plantsRouter from './routes/plants.js';
import sensorRouter from './routes/sensor.js';
import { sendError } from './utils/errors.js';

const app = express();
app.use(express.json());

// ベースURLは 設計書5章の通り http://<server-ip>:port/api
app.use('/api/plants', plantsRouter);
app.use('/api/sensor', sensorRouter);

// 未定義のルート
app.use((req, res) => {
  sendError(res, 404, 'NOT_FOUND', '指定されたエンドポイントは存在しません');
});

// エラーハンドラ(設計書5-8)
//
// express.json() はリクエストボディのJSONが壊れていると
// SyntaxError(err.type === 'entity.parse.failed')をここに渡してくる。
// これはクライアント側の不正なリクエストなので400、
// それ以外の想定外のエラーは500として区別する。
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed' || err instanceof SyntaxError) {
    console.warn('JSONパースエラー:', err.message);
    return sendError(
      res,
      400,
      'INVALID_JSON',
      'リクエストボディのJSONが不正です(クォートの壊れ・文字コードなどを確認してください)',
    );
  }

  console.error(err);
  sendError(res, 500, 'INTERNAL_ERROR', 'サーバー内部エラーが発生しました');
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => {
  console.log(`植物見守り API サーバー起動: http://localhost:${PORT}/api`);
});
