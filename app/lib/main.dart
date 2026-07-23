import 'package:flutter/material.dart';

import 'repositories/dummy_plant_repository.dart';
import 'screens/main_page.dart';
import 'state/plant_store.dart';
import 'state/plant_store_scope.dart';
import 'theme/app_theme.dart';

void main() {
  // 実サーバーができたらDummyPlantRepository()を
  // HttpPlantRepository()に差し替えるだけで良い。
  final store = PlantStore(DummyPlantRepository())..loadInitial();

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
