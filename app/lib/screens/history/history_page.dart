import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('履歴', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        const _HistoryCard(
          title: '🌡 温度',
          values: ['24℃', '25℃', '24℃', '23℃'],
        ),
        const SizedBox(height: AppSpacing.medium),
        const _HistoryCard(
          title: '💧 湿度',
          values: ['60%', '58%', '59%', '61%'],
        ),
        const SizedBox(height: AppSpacing.medium),
        const _HistoryCard(
          title: '🪴 土壌水分',
          values: ['45%', '42%', '40%', '38%'],
        ),
        const SizedBox(height: AppSpacing.medium),
        const _HistoryCard(
          title: '☀️ 照度',
          values: ['320 lx', '300 lx', '280 lx', '310 lx'],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final List<String> values;

  const _HistoryCard({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            ...values.map(Text.new),
          ],
        ),
      ),
    );
  }
}
