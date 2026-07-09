import 'package:flutter/material.dart';
import 'screens/main_page.dart';

void main() {
  runApp(const PlantMonitoringApp());
}

class PlantMonitoringApp extends StatelessWidget {
  const PlantMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '植物見守り',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}
