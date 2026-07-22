import 'package:flutter/material.dart';

import '../../data/dummy_plants.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/plant_card.dart';
import '../../widgets/status_hero_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final plant = dummyPlant;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        StatusHeroCard(plant: plant),
        const SizedBox(height: AppSpacing.medium),
        PlantCard(
          temperature: '${plant.temperature}℃',
          humidity: '${plant.humidity}%',
          soilMoisture: '${plant.soilMoisture}%',
          illuminance: '${plant.illuminance} lx',
        ),
      ],
    );
  }
}
