import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'repositories/http_plant_repository.dart';
import 'screens/main_page.dart';
import 'state/plant_store.dart';
import 'state/plant_store_scope.dart';
import 'theme/app_theme.dart';

void main() {
  final store = PlantStore(HttpPlantRepository(baseUrl: ApiConfig.baseUrl))
    ..loadInitial()
    ..startPolling(); // 30秒ごとにplant/notificationsを裏で自動更新する

  runApp(PlantMonitoringApp(store: store));
}

class PlantMonitoringApp extends StatefulWidget {
  final PlantStore store;

  const PlantMonitoringApp({super.key, required this.store});

  @override
  State<PlantMonitoringApp> createState() => _PlantMonitoringAppState();
}

class _PlantMonitoringAppState extends State<PlantMonitoringApp> {
  @override
  void dispose() {
    widget.store.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantStoreScope(
      store: widget.store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '植物見守り',
        theme: AppTheme.light,
        home: const MainPage(),
      ),
    );
  }
}
