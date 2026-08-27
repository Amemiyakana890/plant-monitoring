import { Router } from 'express';
import {
  listDevices,
  getDevice,
  pairDevice,
  unpairDevice,
} from '../controllers/devicesController.js';
import {
  registerDeviceToken,
  deleteDeviceToken,
} from '../controllers/deviceTokensController.js';

const router = Router();

// POST /devices/pair・PUT・DELETE /devices/tokens は、いずれも
// GET/DELETE /devices/:id とパスが被らないよう、パラメータ付きルートより
// 先に定義する(Expressのルートは定義順でマッチするため、後ろにすると
// :idに'pair'や'tokens'という文字列が入ってしまう)。
router.post('/pair', pairDevice);
router.put('/tokens', registerDeviceToken);
router.delete('/tokens', deleteDeviceToken);
router.get('/', listDevices);
router.get('/:id', getDevice);
router.delete('/:id', unpairDevice);

export default router;
