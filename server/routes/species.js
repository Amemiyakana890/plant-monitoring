import { Router } from 'express';
import { getSpeciesCatalog } from '../controllers/speciesController.js';

const router = Router();

// GET /species
router.get('/', getSpeciesCatalog);

export default router;
