import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// 温度・湿度・土壌水分・照度をまとめて表示するカード。
class PlantCard extends StatelessWidget {
  final String temperature;
  final String humidity;
  final String soilMoisture;
  final String illuminance;

  const PlantCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.illuminance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('環境データ', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _ValueRow(icon: '🌡', label: '温度', value: temperature),
            const SizedBox(height: AppSpacing.extraSmall),
            _ValueRow(icon: '💧', label: '湿度', value: humidity),
            const SizedBox(height: AppSpacing.extraSmall),
            _ValueRow(icon: '🪴', label: '土壌水分', value: soilMoisture),
            const SizedBox(height: AppSpacing.extraSmall),
            _ValueRow(icon: '☀️', label: '照度', value: illuminance),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$icon $label'),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
