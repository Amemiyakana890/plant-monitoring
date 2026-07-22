import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('通知', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        const Card(
          child: ListTile(
            leading: Icon(Icons.water_drop, color: AppColors.warning),
            title: Text('土壌水分が少なくなっています'),
            subtitle: Text('7/8 10:30'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Card(
          child: ListTile(
            leading: Icon(Icons.thermostat, color: AppColors.error),
            title: Text('室温が30℃を超えました'),
            subtitle: Text('7/7 14:10'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        const Card(
          child: ListTile(
            leading: Icon(Icons.water_drop_outlined, color: AppColors.info),
            title: Text('湿度が低下しています'),
            subtitle: Text('7/6 08:45'),
          ),
        ),
      ],
    );
  }
}
