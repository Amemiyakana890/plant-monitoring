import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'repositories/http_plant_repository.dart';
import 'screens/main_page.dart';
import 'state/plant_store.dart';
import 'state/plant_store_scope.dart';
import 'theme/app_theme.dart';

void main() {
  final store = PlantStore(HttpPlantRepository(baseUrl: ApiConfig.baseUrl))
    ..loadInitial();

  runApp(PlantMonitoringApp(store: store));
}

class PlantMonitoringApp extends StatelessWidget {
  final PlantStore store;

  const PlantMonitoringApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return PlantStoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '植物見守り',
        theme: AppTheme.light,
        home: const MainPage(),
      ),
    );
  }
}
