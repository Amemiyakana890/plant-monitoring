/// Node.jsサーバーのベースURL設定。
///
/// 実行環境によって「localhost」が指す相手が変わるため、動作させる環境に
/// 合わせてbaseUrlを書き換えること。
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
  static const String baseUrl = 'http://192.168.1.7:3000/api';
}
