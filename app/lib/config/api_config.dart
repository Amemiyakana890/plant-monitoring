import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Node.jsサーバーのベースURL設定。
///
/// 値は `.env`(Git管理対象外)の`API_BASE_URL`から読み込みます。
/// 実行環境によって「localhost」が指す相手が変わるため、動作させる環境に
/// 合わせて `.env` の値を書き換えてください(`.env.example`を参照)。
///
/// - 実機のスマホ(同じWi-Fiに接続): PCのLAN IPを指定する
///   例: 'http://192.168.1.10:3000/api'
///   (PC側で `ipconfig`(Windows) / `ifconfig`か`ip a`(Mac/Linux)で確認できる)
/// - Androidエミュレータ: 'http://10.0.2.2:3000/api'
///   (エミュレータから見た「PC自身」を指す特別なIP)
/// - iOSシミュレータ: 'http://localhost:3000/api' でPCのサーバーに届く
///
/// ESP32(センサーデバイス)も同じサーバーへ送信するため、
/// esp32側のSERVER_HOST設定もこのPCのLAN IPに合わせること。
class ApiConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';
}
