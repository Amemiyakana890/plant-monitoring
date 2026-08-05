import 'package:flutter/material.dart';

/// アプリ全体のテーマモード(ライト/ダーク)を保持するコントローラー。
///
/// 現時点ではアプリ再起動をまたいだ保存(永続化)は行わない
/// (設定/デバイス登録画面のUI実装が先行しているフェーズのため)。
/// 永続化する場合はSharedPreferences等をここに追加する想定。
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeController({ThemeMode initial = ThemeMode.light}) : _themeMode = initial;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void setLight() {
    if (_themeMode == ThemeMode.light) return;
    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  void setDark() {
    if (_themeMode == ThemeMode.dark) return;
    _themeMode = ThemeMode.dark;
    notifyListeners();
  }
}
