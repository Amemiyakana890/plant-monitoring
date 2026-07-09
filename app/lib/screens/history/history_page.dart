import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            "履歴",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            color: AppColors.surface,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "🌡 温度",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Divider(),

                  Text("24℃"),
                  Text("25℃"),
                  Text("24℃"),
                  Text("23℃"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: AppColors.surface,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "💧 湿度",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Divider(),

                  Text("60%"),
                  Text("58%"),
                  Text("59%"),
                  Text("61%"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: AppColors.surface,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "🪴 土壌水分",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Divider(),

                  Text("45%"),
                  Text("42%"),
                  Text("40%"),
                  Text("38%"),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}
