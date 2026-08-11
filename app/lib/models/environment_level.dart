/// 温度・湿度・照度の状態(サーバー側 server/utils/plantStatus.js の
/// healthy / caution / needs_care に対応)。
///
/// 土壌水分専用の[PlantStatus](plant.dart 参照。healthy/thirsty/dry)とは
/// 別の語彙。こちらは docs/status-notification-design.md で定義した
/// 「適正/注意/要ケア」の3段階に対応する。
enum EnvironmentLevel {
  healthy,
  caution,
  needsCare,

  /// 湿度・照度はサーバー側で1日1回(15:00)しか評価しないため、
  /// セットアップ直後などまだ一度も評価が行われていない場合がある
  /// (docs 3-6章「評価準備中」表示に対応)。
  unknown;

  /// サーバーのレスポンス(例: "needs_care"、または未評価のnull)から変換する。
  static EnvironmentLevel fromApi(String? value) {
    switch (value) {
      case 'healthy':
        return EnvironmentLevel.healthy;
      case 'caution':
        return EnvironmentLevel.caution;
      case 'needs_care':
        return EnvironmentLevel.needsCare;
      default:
        return EnvironmentLevel.unknown;
    }
  }
}
