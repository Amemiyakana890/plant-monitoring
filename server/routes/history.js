import { Router } from 'express';
import { getHistory } from '../controllers/historyController.js';

const router = Router();

router.get('/:plantId', getHistory);

export default router;
