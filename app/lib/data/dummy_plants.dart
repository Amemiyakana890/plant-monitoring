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

/// v2(複数植物対応、企画書11章「今後の展望」)のプレビュー用ダミーデータ。
/// 現行v1画面(ホーム/植物情報など)では使用せず、[PlantsPage]など
/// 将来の複数植物一覧・詳細画面の下書き用に用意している。
const List<Plant> dummyPlantsList = [
  dummyPlant,
  Plant(
    id: 2,
    name: 'ポトス',
    species: '観葉植物',
    temperature: 23.8,
    humidity: 58,
    soilMoisture: 55,
    illuminance: 280,
    status: PlantStatus.healthy,
    updatedAt: '09:15',
  ),
  Plant(
    id: 3,
    name: '多肉植物',
    species: 'サボテン科',
    temperature: 25.2,
    humidity: 45,
    soilMoisture: 15,
    illuminance: 410,
    status: PlantStatus.dry,
    updatedAt: '11:02',
  ),
];
