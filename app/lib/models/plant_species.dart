/// GET /species (植物種カタログ、F-08・植物切り替え機能) の1件分。
///
/// v1はモンステラ1件のみだが、将来的に選択肢が増えることを見越して
/// 一覧から選ぶ形のUIにしている(screens/plant_info/species_picker_page.dart参照)。
class PlantSpecies {
  final String key;
  final String name;
  final String scientificName;
  final String familyName;
  final String description;
  final List<String> careTips;
  final double soilMoistureHealthyMin;

  const PlantSpecies({
    required this.key,
    required this.name,
    required this.scientificName,
    this.familyName = '',
    this.description = '',
    this.careTips = const [],
    this.soilMoistureHealthyMin = 0,
  });

  factory PlantSpecies.fromJson(Map<String, dynamic> json) {
    return PlantSpecies(
      key: json['key'] as String,
      name: json['name'] as String,
      scientificName: json['scientific_name'] as String? ?? '',
      familyName: json['family_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      careTips: (json['care_tips'] as List<dynamic>? ?? const [])
          .map((tip) => tip as String)
          .toList(),
      soilMoistureHealthyMin:
          (json['soil_moisture_healthy_min'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// GET /plants, GET /plants/:id レスポンス内の`care_profile`
/// (docs/status-notification-design.md 3-1〜3-4章の閾値を、今の季節に
/// 当てはめた「この植物の管理条件」表示用)。
///
/// 季節はサーバー側で現在時刻(JST)から自動判定する(手動切り替えは行わない)。
class CareProfile {
  /// 'summer' / 'winter' / 'default'(春秋)。
  final String season;

  /// 季節の日本語表示(「夏」「冬」「春秋」)。
  final String seasonLabel;

  final double soilHealthyMin;
  final double soilNeedsCareMax;
  final double temperatureHealthyMin;
  final double temperatureHealthyMax;
  final double humidityHealthyMin;
  final double humidityHealthyMax;
  final double illuminanceHealthyMin;

  const CareProfile({
    required this.season,
    required this.seasonLabel,
    required this.soilHealthyMin,
    required this.soilNeedsCareMax,
    required this.temperatureHealthyMin,
    required this.temperatureHealthyMax,
    required this.humidityHealthyMin,
    required this.humidityHealthyMax,
    required this.illuminanceHealthyMin,
  });

  factory CareProfile.fromJson(Map<String, dynamic> json) {
    final soil = json['soil'] as Map<String, dynamic>? ?? {};
    final temperature = json['temperature'] as Map<String, dynamic>? ?? {};
    final humidity = json['humidity'] as Map<String, dynamic>? ?? {};
    final illuminance = json['illuminance'] as Map<String, dynamic>? ?? {};

    double asDouble(Map<String, dynamic> map, String key) =>
        (map[key] as num?)?.toDouble() ?? 0.0;

    return CareProfile(
      season: json['season'] as String? ?? 'default',
      seasonLabel: json['season_label'] as String? ?? '',
      soilHealthyMin: asDouble(soil, 'healthy_min'),
      soilNeedsCareMax: asDouble(soil, 'needs_care_max'),
      temperatureHealthyMin: asDouble(temperature, 'healthy_min'),
      temperatureHealthyMax: asDouble(temperature, 'healthy_max'),
      humidityHealthyMin: asDouble(humidity, 'healthy_min'),
      humidityHealthyMax: asDouble(humidity, 'healthy_max'),
      illuminanceHealthyMin: asDouble(illuminance, 'healthy_min'),
    );
  }
}
