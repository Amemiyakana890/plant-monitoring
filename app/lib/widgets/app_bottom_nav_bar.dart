import 'package:flutter/material.dart';

import '../state/main_tab_controller_scope.dart';

/// ホーム/植物/履歴/通知/設定のボトムナビゲーションバー。
///
/// `MainPage`本体だけでなく、設定配下のサブ画面
/// (デバイス接続・デバイス情報・通知設定・アプリ情報)でも
/// 同じバーを表示するための共通ウィジェット。
///
/// サブ画面(Navigator.pushで開いた別ルート)上でタップされた場合は、
/// 一旦`MainPage`まで戻ってから(pop)、対象のタブへ切り替える。
/// すでに`MainPage`側にいる場合は`canPop()`がfalseになるので、
/// popは行わずタブの切り替えのみ行う。
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MainTabControllerScope.of(context);

    return BottomNavigationBar(
      currentIndex: controller.currentIndex,
      onTap: (index) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
        controller.setIndex(index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
        BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: '植物'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '履歴'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '通知'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}
