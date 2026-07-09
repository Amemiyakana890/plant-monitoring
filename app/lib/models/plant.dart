class Plant {
  final int id;
  final String name;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final String status;
  final String updatedAt;

  const Plant({
    required this.id,
    required this.name,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.status,
    required this.updatedAt,
  });
}
