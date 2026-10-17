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
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 72,
        titleSpacing: 12,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PLANT CARE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFD3E3C8),
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(_titles[currentIndex]),
          ],
        ),
      ),
      body: _pages[currentIndex],
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
