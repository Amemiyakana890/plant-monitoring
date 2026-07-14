import 'package:flutter/material.dart';

import '../../data/dummy_plants.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/home_plant_card.dart';
import '../../widgets/summary_card.dart';
import '../plant_detail/plant_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        const SummaryCard(
          temperature: '24℃',
          humidity: '60%',
          soilMoisture: '45%',
        ),
        const SizedBox(height: AppSpacing.large),
        Text('マイプランツ', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.medium),
        ...dummyPlants.map(
          (plant) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: HomePlantCard(
              name: plant.name,
              status: plant.status,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => PlantDetailPage(plant: plant),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
