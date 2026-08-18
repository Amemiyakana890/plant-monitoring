// 必ず一番最初にimportすること。
// ESモジュールは「自分がimportする依存モジュール」を自身のトップレベル
// コードより先に評価するため、他のimportの間に`dotenv.config()`を
// 直接書いても、それより前に書かれた./routes/plants.js(→db.js)側の
// 評価が先に終わってしまい、db.js側でDB_PATHを読み取れない。
// そのため専用のenv.jsに分離し、一番最初のimportとして読み込む。
import './env.js';

import express from 'express';
import cors from 'cors';

import plantsRouter from './routes/plants.js';
import sensorRouter from './routes/sensor.js';
import historyRouter from './routes/history.js';
import notificationsRouter from './routes/notifications.js';
import devicesRouter from './routes/devices.js';
import settingsRouter from './routes/settings.js';
import speciesRouter from './routes/species.js';
import { sendError } from './utils/errors.js';

const app = express();
app.use(cors());
app.use(express.json());

// ベースURLは 設計書5章の通り http://<server-ip>:port/api
app.use('/api/plants', plantsRouter);
app.use('/api/sensor', sensorRouter);
app.use('/api/history', historyRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/devices', devicesRouter);
app.use('/api/settings', settingsRouter);
app.use('/api/species', speciesRouter);

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
