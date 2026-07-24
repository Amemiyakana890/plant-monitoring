import { Router } from 'express';
import {
  createPlant,
  listPlants,
  getPlant,
  updatePlant,
  deletePlant,
} from '../controllers/plantsController.js';

const router = Router();

router.post('/', createPlant);
router.get('/', listPlants);
router.get('/:id', getPlant);
router.patch('/:id', updatePlant);
router.delete('/:id', deletePlant);

export default router;
