import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/api_config.dart';
import 'config/firebase_config.dart';
import 'repositories/http_plant_repository.dart';
import 'screens/auth_gate.dart';
import 'state/auth_store.dart';
import 'state/auth_store_scope.dart';
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
  final firebaseError = await FirebaseConfig.initialize();

  if (firebaseError != null) {
    runApp(FirebaseSetupErrorApp(message: firebaseError));
    return;
  }

  final authStore = AuthStore();

  // PlantStoreの初期化(loadInitial/startPolling)は、ログイン状態に関わらず
  // ここで開始してしまっている(v2のログインは「本人確認のゲート」としての
  // 導入であり、サーバー側APIはまだトークンを検証しないため、未ログイン中に
  // 通信が始まっても実害はない、という判断)。将来サーバー側にトークン検証を
  // 足す場合は、このタイミングもログイン後に遅らせる形へ見直すこと。
  final store = PlantStore(HttpPlantRepository(baseUrl: ApiConfig.baseUrl))
    ..loadInitial()
    ..startPolling(); // 30秒ごとにplant/notificationsを裏で自動更新する
  final themeController = ThemeController();

  runApp(
    PlantMonitoringApp(
      authStore: authStore,
      store: store,
      themeController: themeController,
    ),
  );
}

class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Firebase設定エラー')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class PlantMonitoringApp extends StatefulWidget {
  final AuthStore authStore;
  final PlantStore store;
  final ThemeController themeController;

  const PlantMonitoringApp({
    super.key,
    required this.authStore,
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
    return AuthStoreScope(
      store: widget.authStore,
      child: PlantStoreScope(
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
              home: const AuthGate(),
            ),
          ),
        ),
      ),
    );
  }
}
