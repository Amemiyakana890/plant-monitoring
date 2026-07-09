import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            "通知",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(
                Icons.water_drop,
                color: Colors.blue,
              ),
              title: Text("モンステラ"),
              subtitle: Text("土壌水分が少なくなっています"),
              trailing: Text(
                "7/8\n10:30",
                textAlign: TextAlign.end,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(
                Icons.thermostat,
                color: Colors.red,
              ),
              title: Text("温度アラート"),
              subtitle: Text("室温が30℃を超えました"),
              trailing: Text(
                "7/7\n14:10",
                textAlign: TextAlign.end,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: AppColors.surface,
            child: const ListTile(
              leading: Icon(
                Icons.water_drop_outlined,
                color: Colors.cyan,
              ),
              title: Text("パキラ"),
              subtitle: Text("湿度が低下しています"),
              trailing: Text(
                "7/6\n08:45",
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
