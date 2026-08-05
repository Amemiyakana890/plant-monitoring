/// 植物の状態(サーバー側の判定ロジック(設計書5-7)に対応するコード値)
enum PlantStatus {
  healthy,
  thirsty,
  dry;

  /// サーバーのレスポンス(例: "healthy")から変換する。
  /// 未知の値が来た場合はhealthy扱いにはせず、明示的にthirsty(要注意)側に
  /// 倒しておく方が「静かに見守る」コンセプト上安全という判断。
  static PlantStatus fromApi(String? value) {
    switch (value) {
      case 'healthy':
        return PlantStatus.healthy;
      case 'dry':
        return PlantStatus.dry;
      case 'thirsty':
        return PlantStatus.thirsty;
      default:
        return PlantStatus.thirsty;
    }
  }

  String toApi() => name;
}

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

  /// 画面表示用に、サーバーのUTC文字列(例: "2026-08-04T01:08:52Z")を
  /// ローカル時刻(JST等)に変換して整形した文字列を返す。
  /// 通知一覧(notification_page.dart の_formatDateTime)と表記を揃え、
  /// 「2026年8月6日 07:57:32」形式にしている。
  /// パースできない場合は元の文字列をそのまま返す(フォールバック)。
  String get updatedAtDisplay {
    if (updatedAt.isEmpty) return '';
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) return updatedAt;

    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}年${local.month}月${local.day}日 '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

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

  /// GET /plants, GET /plants/:id のレスポンス(設計書5-2)から変換する。
  ///
  /// 注意: サーバー側はセンサーデータが1件も届いていない植物について
  /// temperature/humidity/soil/illuminance/updated_at を null で返す
  /// (server/controllers/plantsController.js の toPlantResponse を参照)。
  /// このモデルは現状すべて非null前提のため、ここでは暫定的に0/空文字へ
  /// フォールバックしている。HttpPlantRepository実装時に、画面側で
  /// 「まだデータがありません」を出すか、フィールドをnullableにするか
  /// 決めた上で見直すこと。
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] as int,
      name: json['name'] as String,
      species: json['species'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (json['soil'] as num?)?.toDouble() ?? 0.0,
      illuminance: (json['illuminance'] as num?)?.toDouble() ?? 0.0,
      status: PlantStatus.fromApi(json['status'] as String?),
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  /// PATCH /plants/:id (設計書5-2)向け。編集可能なのは name/species のみ。
  Map<String, dynamic> toUpdateJson() => {'name': name, 'species': species};
}
