import { listSpecies } from '../utils/speciesCatalog.js';

// GET /species
// 植物切り替え機能(植物情報ページの「植物を選択する」)向けのカタログ一覧。
// v1はモンステラ1件のみを返すが、将来種類が増えてもこのAPIの形は変えずに済む。
export function getSpeciesCatalog(req, res) {
  res.json(listSpecies());
}
