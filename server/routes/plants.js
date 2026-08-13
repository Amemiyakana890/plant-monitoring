import { Router } from 'express';
import {
  createPlant,
  listPlants,
  getPlant,
  updatePlant,
  deletePlant,
  recordWatering,
} from '../controllers/plantsController.js';

const router = Router();

router.post('/', createPlant);
router.get('/', listPlants);
router.get('/:id', getPlant);
router.patch('/:id', updatePlant);
router.delete('/:id', deletePlant);
router.post('/:id/waterings', recordWatering);

export default router;
