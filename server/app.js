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

// 想定外のエラー(設計書5-8)
app.use((err, req, res, next) => {
  console.error(err);
  sendError(res, 500, 'INTERNAL_ERROR', 'サーバー内部エラーが発生しました');
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => {
  console.log(`植物見守り API サーバー起動: http://localhost:${PORT}/api`);
});
