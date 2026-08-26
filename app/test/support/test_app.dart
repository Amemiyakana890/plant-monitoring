import 'package:flutter/material.dart';
import 'package:plant_monitoring_app/screens/app_root.dart';
import 'package:plant_monitoring_app/state/main_tab_controller.dart';
import 'package:plant_monitoring_app/state/main_tab_controller_scope.dart';
import 'package:plant_monitoring_app/state/plant_store.dart';
import 'package:plant_monitoring_app/state/plant_store_scope.dart';
import 'package:plant_monitoring_app/state/theme_controller.dart';
import 'package:plant_monitoring_app/state/theme_controller_scope.dart';
import 'package:plant_monitoring_app/theme/app_theme.dart';

/// [PlantMonitoringApp](../../lib/main.dart)から[AuthGate]
/// (Firebase Auth)を取り除いた、テスト専用の簡易版アプリシェル。
///
/// widget_test.dart・app_root_test.dartは「植物登録→ホーム」までの
/// 画面遷移を検証するのが目的で、ログイン機能自体の検証は対象外のため、
/// こちらを使うことでテスト環境にFirebase初期化(Firebase.initializeApp)
/// を用意する手間を避けている。ログイン画面(AuthGate/LoginPage)自体の
/// 検証は別途 test/auth_gate_test.dart で行っている。
///
/// 中身は main.dart の `_PlantMonitoringAppState.build()` から
/// AuthStoreScope/AuthGate を取り除いただけで、それ以外の構造
/// (Scopeの並び順・MainTabControllerの持たせ方)は完全に揃えている。
class TestApp extends StatefulWidget {
  const TestApp({
    super.key,
    required this.store,
    required this.themeController,
  });

  final PlantStore store;
  final ThemeController themeController;

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  final MainTabController _tabController = MainTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
            home: const AppRoot(),
          ),
        ),
      ),
    );
  }
}
