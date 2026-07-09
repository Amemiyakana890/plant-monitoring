import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SummaryCard extends StatelessWidget {
  final String temperature;
  final String humidity;
  final String soilMoisture;

  const SummaryCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  "今日のまとめ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🌡 平均温度"),
                Text(temperature),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("💧 平均湿度"),
                Text(humidity),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🪴 平均土壌水分"),
                Text(soilMoisture),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
