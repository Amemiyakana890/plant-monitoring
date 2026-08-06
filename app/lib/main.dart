import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/api_config.dart';
import 'repositories/http_plant_repository.dart';
import 'screens/main_page.dart';
import 'state/main_tab_controller.dart';
import 'state/main_tab_controller_scope.dart';
import 'state/plant_store.dart';
import 'state/plant_store_scope.dart';
import 'state/theme_controller.dart';
import 'state/theme_controller_scope.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // .env が無い場合は例外になるので事前に作成しておくこと

  final store = PlantStore(HttpPlantRepository(baseUrl: ApiConfig.baseUrl))
    ..loadInitial()
    ..startPolling(); // 30秒ごとにplant/notificationsを裏で自動更新する
  final themeController = ThemeController();

  runApp(PlantMonitoringApp(store: store, themeController: themeController));
}

class PlantMonitoringApp extends StatefulWidget {
  final PlantStore store;
  final ThemeController themeController;

  const PlantMonitoringApp({
    super.key,
    required this.store,
    required this.themeController,
  });

  @override
  State<PlantMonitoringApp> createState() => _PlantMonitoringAppState();
}

class _PlantMonitoringAppState extends State<PlantMonitoringApp> {
  // 選択中のボトムナビゲーションタブの状態。MainPageより外側(Navigatorより
  // 外側)に置くことで、設定配下のサブ画面(Navigator.pushで開く別ルート)
  // からも同じ状態を参照・変更できるようにする(AppBottomNavBar参照)。
  final MainTabController _tabController = MainTabController();

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.store.stopPolling();
    widget.themeController.removeListener(_onThemeChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return PlantStoreScope(
      store: widget.store,
      child: ThemeControllerScope(
        controller: widget.themeController,
        child: MainTabControllerScope(
          controller: _tabController,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '植物見守り',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: widget.themeController.themeMode,
            home: const MainPage(),
          ),
        ),
      ),
    );
  }
}
