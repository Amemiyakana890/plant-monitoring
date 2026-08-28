import 'environment_level.dart';
import 'plant_species.dart';

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
  final int? deviceId;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double illuminance;
  final PlantStatus status;
  final String updatedAt;

  // --- 温度・湿度・照度の状態判定(docs/status-notification-design.md) ---
  // 土壌水分(status)とは別に、サーバー側 utils/plantStatus.js が算出する
  // 「適正/注意/要ケア」を保持する。ホーム画面の各カードのバッジ表示に使う
  // (widgets/plant_card.dart 参照)。

  /// 温度はリアルタイム・継続時間ベースで評価されるため、常に値が入っている
  /// (サーバー側のデフォルトは'healthy')。
  final EnvironmentLevel tempStatus;

  /// 湿度は1日1回(15:00)の日次評価(docs 3-2章)。
  /// セットアップ直後などまだ一度も評価されていない場合は[EnvironmentLevel.unknown]。
  final EnvironmentLevel humidityDailyStatus;

  /// 直近の日次評価時点での24時間平均湿度(%)。未評価ならnull。
  final double? humidityDailyAvg;

  /// 直近の日次評価が実施された時刻(UTC・ISO8601)。未評価ならnull。
  final String? humidityEvaluatedAt;

  /// 照度は1日1回(15:00)の日次評価、昼間(6:00〜18:00, JST)平均(docs 3-4章)。
  final EnvironmentLevel illuminanceDailyStatus;

  /// 直近の日次評価時点での昼間平均照度(lux)。未評価ならnull。
  final double? illuminanceDailyAvg;

  /// 直近の日次評価が実施された時刻(UTC・ISO8601)。未評価ならnull。
  final String? illuminanceEvaluatedAt;

  /// 直近の水やり記録時刻(UTC・ISO8601、docs 4-2章)。
  /// センサーからは分からないため、ホーム画面の「水やりした」ボタン
  /// (widgets/plant_card.dart)から明示的に記録する。一度も記録が無ければnull。
  final String? lastWateredAt;

  /// 選択されている植物種のキー(例: "monstera")。未選択ならnull
  /// (F-08実装前に作成された植物、またはまだ一度も選択していない場合)。
  final String? speciesKey;

  /// 選択されている植物種の表示情報。speciesKeyが未選択でも、サーバー側で
  /// デフォルト種(モンステラ)にフォールバックした値が必ず入っている
  /// (server/utils/speciesCatalog.jsのgetSpeciesInfo参照)。
  final PlantSpecies speciesInfo;

  /// 今の季節・選択されている植物種に基づく「管理条件」
  /// (植物情報ページの表示用、docs 3-1〜3-4章)。speciesInfoと同じく
  /// 未選択でも常にフォールバック値が入っている。
  final CareProfile careProfile;

  const Plant({
    required this.id,
    required this.name,
    required this.species,
    this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
    required this.status,
    required this.updatedAt,
    this.tempStatus = EnvironmentLevel.healthy,
    this.humidityDailyStatus = EnvironmentLevel.unknown,
    this.humidityDailyAvg,
    this.humidityEvaluatedAt,
    this.illuminanceDailyStatus = EnvironmentLevel.unknown,
    this.illuminanceDailyAvg,
    this.illuminanceEvaluatedAt,
    this.lastWateredAt,
    this.speciesKey,
    this.speciesInfo = const PlantSpecies(
      key: 'monstera',
      name: 'モンステラ',
      scientificName: 'サトイモ科モンステラ属',
    ),
    this.careProfile = const CareProfile(
      season: 'summer',
      seasonLabel: '夏',
      soilHealthyMin: 40,
      soilNeedsCareMax: 20,
      temperatureHealthyMin: 18,
      temperatureHealthyMax: 30,
      humidityHealthyMin: 60,
      humidityHealthyMax: 80,
      illuminanceHealthyMin: 1000,
    ),
  });

  /// 画面表示用に、サーバーのUTC文字列(例: "2026-08-04T01:08:52Z")を
  /// ローカル時刻(JST等)に変換して整形した文字列を返す。
  /// 通知一覧(notification_page.dart の_formatDateTime)と表記を揃え、
  /// 「2026年8月6日 07:57:32」形式にしている。
  /// パースできない場合は元の文字列をそのまま返す(フォールバック)。
  String get updatedAtDisplay => _formatDateTime(updatedAt, withSeconds: true);

  /// 湿度の日次評価時刻を「8月10日 15:00時点」の形式で返す。
  /// 未評価(null)の場合は空文字を返す(呼び出し側で「評価準備中」等に出し分ける)。
  String get humidityEvaluatedAtDisplay =>
      _formatEvaluatedAt(humidityEvaluatedAt);

  /// 照度の日次評価時刻を「8月10日 15:00時点」の形式で返す。
  String get illuminanceEvaluatedAtDisplay =>
      _formatEvaluatedAt(illuminanceEvaluatedAt);

  /// 最後の水やりからの経過時間を「3時間前」のような相対表記で返す。
  /// 一度も記録が無い場合は「まだ記録がありません」を返す。
  ///
  /// [now]はテスト容易性のための引数(省略時は実行時刻)。
  /// server側の各判定関数(例: resolveTemperatureStatus)と同じく、
  /// 呼び出し側から時刻を注入できるようにしている。
  String lastWateredAtDisplay({DateTime? now}) {
    if (lastWateredAt == null || lastWateredAt!.isEmpty) {
      return 'まだ記録がありません';
    }
    final parsed = DateTime.tryParse(lastWateredAt!);
    if (parsed == null) return lastWateredAt!;

    final current = now ?? DateTime.now();
    final diff = current.difference(parsed.toLocal());

    // 未来の時刻(サーバー・端末間の時計のズレなど)は「たった今」に丸める。
    if (diff.isNegative || diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    return '${diff.inDays}日前';
  }

  static String _formatEvaluatedAt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final formatted = _formatDateTime(iso, withSeconds: false);
    if (formatted.isEmpty) return '';
    return '$formatted時点の評価';
  }

  static String _formatDateTime(String iso, {required bool withSeconds}) {
    if (iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;

    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final datePart = '${local.year}年${local.month}月${local.day}日';
    final timePart = withSeconds
        ? '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
        : '${two(local.hour)}:${two(local.minute)}';
    return '$datePart $timePart';
  }

  /// [deviceId]は明示的にnullを渡したいケース(ペアリング解除)があるため、
  /// 「未指定(現在の値を維持)」と「nullにしたい」を区別できるよう
  /// [clearDeviceId]で切り替える(単純に`deviceId: null`だと区別できないため)。
  ///
  /// 注意: 実際のペアリング解除はサーバー側のON DELETE SET NULL(6章)で
  /// 自動的に行われるため、通常はDELETE /devices/:id → fetchPlant()で
  /// 再取得する形を使う。このcopyWithの[clearDeviceId]はローカルの
  /// 楽観的更新など、サーバーを介さずUI側の状態だけ先に変えたい場合向け。
  ///
  /// [lastWateredAt]は「水やりした」ボタンの楽観的更新(state/plant_store.dart
  /// のrecordWatering)専用。サーバーからの正式な値は次のfetchPlant()で
  /// 上書きされる想定。
  Plant copyWith({
    String? name,
    String? species,
    int? deviceId,
    bool clearDeviceId = false,
    String? lastWateredAt,
    String? speciesKey,
    PlantSpecies? speciesInfo,
    CareProfile? careProfile,
  }) {
    return Plant(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      illuminance: illuminance,
      status: status,
      updatedAt: updatedAt,
      tempStatus: tempStatus,
      humidityDailyStatus: humidityDailyStatus,
      humidityDailyAvg: humidityDailyAvg,
      humidityEvaluatedAt: humidityEvaluatedAt,
      illuminanceDailyStatus: illuminanceDailyStatus,
      illuminanceDailyAvg: illuminanceDailyAvg,
      illuminanceEvaluatedAt: illuminanceEvaluatedAt,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
      speciesKey: speciesKey ?? this.speciesKey,
      speciesInfo: speciesInfo ?? this.speciesInfo,
      careProfile: careProfile ?? this.careProfile,
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
      deviceId: json['device_id'] as int?,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (json['soil'] as num?)?.toDouble() ?? 0.0,
      illuminance: (json['illuminance'] as num?)?.toDouble() ?? 0.0,
      status: PlantStatus.fromApi(json['status'] as String?),
      updatedAt: json['updated_at'] as String? ?? '',
      // temp_status未指定時(センサー未受信でまだ一度も判定されていない場合)は
      // EnvironmentLevel.fromApi(null)のデフォルトであるunknownではなく、
      // コンストラクタのデフォルト値と同じhealthyにフォールバックする。
      // 温度はリアルタイム評価のため「未評価ならunknown(評価準備中)」という
      // 湿度・照度側の意味づけは合わず、「まだ悪化が検知されていない=健康」
      // として扱う(models_test.dart参照)。
      tempStatus: json['temp_status'] == null
          ? EnvironmentLevel.healthy
          : EnvironmentLevel.fromApi(json['temp_status'] as String?),
      humidityDailyStatus: EnvironmentLevel.fromApi(
        json['humidity_daily_status'] as String?,
      ),
      humidityDailyAvg: (json['humidity_daily_avg'] as num?)?.toDouble(),
      humidityEvaluatedAt: json['humidity_evaluated_at'] as String?,
      illuminanceDailyStatus: EnvironmentLevel.fromApi(
        json['illuminance_daily_status'] as String?,
      ),
      illuminanceDailyAvg: (json['illuminance_daily_avg'] as num?)?.toDouble(),
      illuminanceEvaluatedAt: json['illuminance_evaluated_at'] as String?,
      lastWateredAt: json['last_watered_at'] as String?,
      speciesKey: json['species_key'] as String?,
      speciesInfo: json['species_info'] is Map<String, dynamic>
          ? PlantSpecies.fromJson(json['species_info'] as Map<String, dynamic>)
          : const PlantSpecies(
              key: 'monstera',
              name: 'モンステラ',
              scientificName: 'サトイモ科モンステラ属',
            ),
      careProfile: json['care_profile'] is Map<String, dynamic>
          ? CareProfile.fromJson(json['care_profile'] as Map<String, dynamic>)
          : const CareProfile(
              season: 'summer',
              seasonLabel: '夏',
              soilHealthyMin: 40,
              soilNeedsCareMax: 20,
              temperatureHealthyMin: 18,
              temperatureHealthyMax: 30,
              humidityHealthyMin: 60,
              humidityHealthyMax: 80,
              illuminanceHealthyMin: 1000,
            ),
    );
  }

  /// PATCH /plants/:id (設計書5-2)向け。編集可能なのは name/species のみ。
  Map<String, dynamic> toUpdateJson() => {'name': name, 'species': species};
}
