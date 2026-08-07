import { Router } from 'express';
import {
  listDevices,
  getDevice,
  pairDevice,
  unpairDevice,
} from '../controllers/devicesController.js';

const router = Router();

// POST /devices/pair は POST /devices/:id とパスが被らないよう
// パラメータ付きルートより先に定義する(Expressのルートは定義順で
// マッチするため、後ろにすると:idに'pair'という文字列が入ってしまう)。
router.post('/pair', pairDevice);
router.get('/', listDevices);
router.get('/:id', getDevice);
router.delete('/:id', unpairDevice);

export default router;
