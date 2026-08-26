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

  final store = PlantStore(
    HttpPlantRepository(baseUrl: ApiConfig.baseUrl),
  );
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
  bool _loadedForCurrentSession = false;

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_onThemeChanged);
    widget.authStore.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    widget.store.stopPolling();
    widget.themeController.removeListener(_onThemeChanged);
    widget.authStore.removeListener(_onAuthChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  void _onAuthChanged() {
    if (widget.authStore.isSignedIn && !_loadedForCurrentSession) {
      _loadedForCurrentSession = true;
      widget.store.loadInitial();
      widget.store.startPolling();
    } else if (!widget.authStore.isSignedIn) {
      _loadedForCurrentSession = false;
      widget.store.stopPolling();
    }
  }

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
