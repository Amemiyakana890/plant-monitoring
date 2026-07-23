import { Router } from 'express';
import { createPlant, listPlants, getPlant } from '../controllers/plantsController.js';

const router = Router();

router.post('/', createPlant);
router.get('/', listPlants);
router.get('/:id', getPlant);

export default router;
