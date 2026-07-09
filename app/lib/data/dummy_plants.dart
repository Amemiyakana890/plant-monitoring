import '../models/plant.dart';

const List<Plant> dummyPlants = [

  Plant(
    id: 1,
    name: "モンステラ",
    temperature: 24,
    humidity: 60,
    soilMoisture: 45,
    status: "元気です 🌿",
    updatedAt: "10:30",
  ),

  Plant(
    id: 2,
    name: "パキラ",
    temperature: 25,
    humidity: 58,
    soilMoisture: 40,
    status: "少し乾いています 🌱",
    updatedAt: "10:25",
  ),

  Plant(
    id: 3,
    name: "サボテン",
    temperature: 26,
    humidity: 40,
    soilMoisture: 20,
    status: "乾燥しています 🍂",
    updatedAt: "10:20",
  ),

];
