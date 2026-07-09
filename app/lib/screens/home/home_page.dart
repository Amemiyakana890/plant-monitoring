import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/home_plant_card.dart';
import '../../data/dummy_plants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SummaryCard(
              temperature: "24℃",
              humidity: "60%",
              soilMoisture: "45%",
            ),

            const SizedBox(height: 24),

            const Text(
              "マイプランツ",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            ...dummyPlants.map(
              (plant) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),

                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${plant.name}の詳細画面（作成予定）"),
                      ),
                    );
                  },

                  child: HomePlantCard(
                    name: plant.name,
                    status: plant.status,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
