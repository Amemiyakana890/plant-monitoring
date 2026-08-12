import { Router } from 'express';
import {
  getNotificationSettings,
  updateNotificationSettings,
} from '../controllers/settingsController.js';

const router = Router();

// 設計書5-1: GET/PUT /settings/notification
router.get('/notification', getNotificationSettings);
router.put('/notification', updateNotificationSettings);

export default router;
