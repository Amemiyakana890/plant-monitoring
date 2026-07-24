import '../models/plant.dart';

/// v1は1台のデバイス・1株の植物のみを管理する単独構成のため、
/// リストではなく単一のPlantを保持する。
const Plant dummyPlant = Plant(
  id: 1,
  name: 'モンステラ',
  species: '観葉植物',
  temperature: 24.5,
  humidity: 60,
  soilMoisture: 42,
  illuminance: 320,
  status: PlantStatus.thirsty,
  updatedAt: '10:30',
);

// 複数植物対応(企画書11章「今後の展望」)は、GET /plants がリストを返す
// v2 APIに合わせて着手する。それまでは PlantStore / PlantRepository ともに
// 単一の Plant のみを扱う設計に統一する(以前あった PlantsPage 等の
// 複数植物プレビューは、Store を経由しない孤立コードだったため一旦削除した)。
