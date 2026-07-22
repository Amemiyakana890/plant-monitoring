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
