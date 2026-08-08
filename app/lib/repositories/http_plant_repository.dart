import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';
import '../models/environment_log.dart';
import '../models/plant.dart';
import '../models/plant_notification.dart';
import 'plant_repository.dart';

/// [PlantRepository]の本実装。Node.js + SQLiteサーバー(server/)と通信する。
///
/// v1は「1台のデバイス・1株の植物のみ」という制約(要件定義書9章)のため、
/// [PlantRepository]のインターフェース自体がplant_idを引数に取らない設計に
/// なっている。history/notificationsのAPIはplant_idを必要とするため、
/// ここで最初に GET /plants を1回叩いてplant_idを解決し、以降はキャッシュして
/// 使い回す(loadInitial()がloadPlant()とloadNotifications()を並列実行する
/// ため、Futureをキャッシュして二重に問い合わせないようにしている)。
class HttpPlantRepository implements PlantRepository {
  HttpPlantRepository({required this.baseUrl});

  /// 例: 'http://192.168.1.10:3000/api'。詳細は[ApiConfig]参照。
  final String baseUrl;

  Future<int>? _plantIdFuture;

  Future<int> _resolvePlantId() => _plantIdFuture ??= _fetchFirstPlantId();

  Future<int> _fetchFirstPlantId() async {
    final list = await _fetchPlantList();
    return list.first['id'] as int;
  }

  Future<List<Map<String, dynamic>>> _fetchPlantList() async {
    final uri = Uri.parse('$baseUrl/plants');
    final res = await http.get(uri);
    _ensureOk(res, 'GET /plants');

    final list = jsonDecode(res.body) as List<dynamic>;
    if (list.isEmpty) {
      // v1では植物登録画面からの新規作成フローがまだHTTPに繋がっていないため、
      // 初回は `curl -X POST $baseUrl/plants -d '{"name":"モンステラ"}'` などで
      // 1件だけ手動登録しておく必要がある。
      throw StateError('まだ植物が登録されていません。先に POST /plants で植物を1件登録してください。');
    }
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<Plant> fetchPlant() async {
    final list = await _fetchPlantList();
    final json = list.first;
    _plantIdFuture = Future.value(json['id'] as int);
    return Plant.fromJson(json);
  }

  @override
  Future<Plant> updatePlant({String? name, String? species, int? deviceId}) async {
    final id = await _resolvePlantId();
    final uri = Uri.parse('$baseUrl/plants/$id');
    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      // deviceId未指定時はnullを送るが、サーバー側はCOALESCEで現在値を
      // 維持するだけなので、既存の紐付けを壊すことはない(設計書5-2参照)。
      body: jsonEncode({'name': name, 'species': species, 'device_id': deviceId}),
    );
    _ensureOk(res, 'PATCH /plants/$id');
    return Plant.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<List<EnvironmentLog>> fetchHistory({String range = '7d'}) async {
    final id = await _resolvePlantId();
    final uri = Uri.parse('$baseUrl/history/$id?range=$range');
    final res = await http.get(uri);
    _ensureOk(res, 'GET /history/$id');

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final logs = (json['logs'] as List<dynamic>? ?? []);
    return logs
        .map(
          (e) => EnvironmentLog.fromJson(
            e as Map<String, dynamic>,
            label: _shortDateLabel(e['created_at'] as String?),
          ),
        )
        .toList();
  }

  @override
  Future<List<PlantNotification>> fetchNotifications() async {
    final uri = Uri.parse('$baseUrl/notifications');
    final res = await http.get(uri);
    _ensureOk(res, 'GET /notifications');

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => PlantNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlantNotification> markNotificationRead(int id) async {
    final uri = Uri.parse('$baseUrl/notifications/$id');
    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_read': true}),
    );
    _ensureOk(res, 'PATCH /notifications/$id');
    return PlantNotification.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ---- 設計書5-3 デバイスAPI ----

  @override
  Future<List<Device>> fetchDevices() async {
    final uri = Uri.parse('$baseUrl/devices');
    final res = await http.get(uri);
    _ensureOk(res, 'GET /devices');

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Device> fetchDevice(int id) async {
    final uri = Uri.parse('$baseUrl/devices/$id');
    final res = await http.get(uri);
    _ensureOk(res, 'GET /devices/$id');
    return Device.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<Device> pairDevice({
    required String deviceName,
    required String macAddress,
  }) async {
    final uri = Uri.parse('$baseUrl/devices/pair');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_name': deviceName, 'mac_address': macAddress}),
    );

    // サーバー側(2026-08-07以降)は、同じmac_addressのデバイスが既に存在する
    // 場合はエラーにせず、既存の行を再アクティブ化して200 OKで返す仕様に
    // なっている(devicesController.js参照)。そのため201/200どちらでも
    // 同じように扱えば良く、以前あった「409を捕まえて既存デバイスを
    // 探しにいく」フォールバックは不要になった。
    _ensureOk(res, 'POST /devices/pair');
    return Device.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<void> unpairDevice(int id) async {
    final uri = Uri.parse('$baseUrl/devices/$id');
    final res = await http.delete(uri);
    _ensureOk(res, 'DELETE /devices/$id');
  }

  void _ensureOk(http.Response res, String label) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        '$label に失敗しました (status: ${res.statusCode}, body: ${res.body})',
      );
    }
  }

  /// created_at(ISO8601、例: '2026-07-28T10:35:00')から
  /// 履歴グラフ表示用の短いラベル(例: '7/28')を作る。
  /// intlパッケージを追加せずに済むよう文字列操作のみで済ませている。
  String? _shortDateLabel(String? isoString) {
    if (isoString == null || isoString.length < 10) return isoString;
    final parts = isoString.substring(0, 10).split('-'); // 'YYYY-MM-DD'
    if (parts.length != 3) return isoString;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return isoString;
    return '$month/$day';
  }
}
