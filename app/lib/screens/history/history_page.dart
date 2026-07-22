import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/history_line_chart.dart';

/// 過去7日分の環境データをダミーで持つ(実際はGET /history/:plantIdから取得する想定。
/// 設計書5-5のrangeパラメータに対応する期間切り替えは今後実装予定)。
const _labels = ['7/16', '7/17', '7/18', '7/19', '7/20', '7/21', '7/22'];

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('履歴', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        const HistoryLineChart(
          title: '🌡 温度',
          unit: '℃',
          color: AppColors.warning,
          labels: _labels,
          values: [23, 24, 25, 24.5, 26, 25, 24.5],
        ),
        const SizedBox(height: AppSpacing.medium),
        const HistoryLineChart(
          title: '💧 湿度',
          unit: '%',
          color: AppColors.info,
          labels: _labels,
          values: [58, 61, 59, 60, 57, 62, 60],
        ),
        const SizedBox(height: AppSpacing.medium),
        const HistoryLineChart(
          title: '🪴 土壌水分',
          unit: '%',
          color: AppColors.primary,
          labels: _labels,
          values: [55, 50, 46, 44, 40, 40, 42],
        ),
        const SizedBox(height: AppSpacing.medium),
        const HistoryLineChart(
          title: '☀️ 照度',
          unit: ' lx',
          color: AppColors.accent,
          labels: _labels,
          values: [300, 340, 280, 320, 350, 310, 320],
        ),
      ],
    );
  }
}
