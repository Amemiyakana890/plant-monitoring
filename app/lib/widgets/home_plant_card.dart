import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HomePlantCard extends StatelessWidget {
  final String name;
  final String status;
  final IconData icon;
  final VoidCallback? onTap;

  const HomePlantCard({
    super.key,
    required this.name,
    required this.status,
    this.icon = Icons.local_florist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: AppColors.primary,
        ),
        title: Text(name),
        subtitle: Text(status),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
