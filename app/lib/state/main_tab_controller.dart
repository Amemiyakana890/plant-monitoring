import 'package:flutter/material.dart';

/// ボトムナビゲーション(ホーム/植物/履歴/通知/設定)の選択中タブを保持する
/// コントローラー。
///
/// 設定配下のサブ画面(デバイス情報・通知設定・デバイス接続・アプリ情報)は
/// `Navigator.push`で開く別ルートのため、`MainPage`が管理するタブの状態を
/// そのままでは参照できない。このコントローラーを`main.dart`側で
/// `MainPage`より外側(Navigatorより外側)にスコープしておくことで、
/// サブ画面からも「どのタブが選ばれているか」を参照したり、
/// タブを切り替えたりできるようにする。
class MainTabController extends ChangeNotifier {
  int _currentIndex;

  MainTabController({int initialIndex = 0}) : _currentIndex = initialIndex;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }
}
