/// 植物の状態(サーバー側の判定ロジック(設計書5-7)に対応するコード値)
enum PlantStatus { healthy, thirsty, dry }

class Plant {
  final int id;
  final String name;
  final String species;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double illuminance;
  final PlantStatus status;
  final String updatedAt;

  const Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
    required this.status,
    required this.updatedAt,
  });

  Plant copyWith({String? name, String? species}) {
    return Plant(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      illuminance: illuminance,
      status: status,
      updatedAt: updatedAt,
    );
  }
}
