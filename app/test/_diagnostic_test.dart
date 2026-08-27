import 'package:flutter_test/flutter_test.dart';

/// 環境側(タイマー・イベントループ)の問題かどうかを切り分けるための
/// 最小限のテスト。PlantStore・DummyPlantRepositoryのコードは一切使わず、
/// 素のFuture.delayedだけで完了するかを確認する。
/// (原因特定後にこのファイルは削除してよい)
void main() {
  test('素のFuture.delayedが完了する(testのみ、testWidgetsではない)', () async {
    // ignore: avoid_print
    print('[DEBUG] start');
    await Future.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('[DEBUG] after delay');
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('素のFuture.delayedが完了する(testWidgets)', (tester) async {
    // ignore: avoid_print
    print('[DEBUG] widget start');
    await Future.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('[DEBUG] widget after delay');
  }, timeout: const Timeout(Duration(seconds: 10)));
}
