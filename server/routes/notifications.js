import { Router } from 'express';
import {
  listNotifications,
  markNotificationRead,
} from '../controllers/notificationsController.js';

const router = Router();

router.get('/', listNotifications);
router.patch('/:id', markNotificationRead);

export default router;
