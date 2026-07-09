import 'package:flutter/material.dart';
import '../theme/app_colors.dart';


class PlantCard extends StatelessWidget {
  final String name;
  final String temperature;
  final String humidity;
  final String soilMoisture;
  final String status;
  final String updatedAt;
  final IconData icon;

  const PlantCard({
    super.key,
    required this.name,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.status,
    required this.updatedAt,
    this.icon = Icons.local_florist,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text("🌡 温度　$temperature"),
            Text("💧 湿度　$humidity"),
            Text("🪴 土壌水分　$soilMoisture"),

            const SizedBox(height: 12),

            Text("状態：$status"),

            const Divider(),

            Text(
              "最終更新：$updatedAt",
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
