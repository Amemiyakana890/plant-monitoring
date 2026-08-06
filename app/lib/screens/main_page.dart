import 'package:flutter/material.dart';

import '../state/main_tab_controller_scope.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'history/history_page.dart';
import 'home/home_page.dart';
import 'notification/notification_page.dart';
import 'plant_info/plant_info_page.dart';
import 'settings/settings_page.dart';

const List<String> _titles = ['植物見守り', '植物情報', '履歴', '通知', '設定'];

const List<Widget> _pages = [
  HomePage(),
  PlantInfoPage(),
  HistoryPage(),
  NotificationPage(),
  SettingsPage(),
];

/// アプリのメイン画面(タブ本体)。
///
/// 選択中のタブは`MainTabControllerScope`経由で取得するため、
/// このウィジェット自体はタブの状態を持たない(StatelessWidget)。
/// タブの状態を外部のコントローラーに持たせているのは、設定配下の
/// サブ画面(`Navigator.push`で開く別ルート)からも同じタブ状態を
/// 参照・変更できるようにするため(`AppBottomNavBar`参照)。
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentIndex = MainTabControllerScope.of(context).currentIndex;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[currentIndex])),
      body: _pages[currentIndex],
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
