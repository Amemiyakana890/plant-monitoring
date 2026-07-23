import 'package:flutter/material.dart';

import '../../state/plant_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/history_line_chart.dart';

/// 過去の環境データをグラフで確認する画面。
/// データは[PlantStore]経由で取得する(設計書5-5 GET /history/:plantId 相当。
/// range切り替えのUIは今後実装予定で、現状は7d固定)。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回表示時にまだ履歴を取得していなければ取得する。
    if (_requested) return;
    _requested = true;
    final store = PlantStoreScope.of(context);
    if (store.history.isEmpty && !store.isLoadingHistory) {
      store.loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final logs = store.history;

    if (store.isLoadingHistory && logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (logs.isEmpty) {
      return const Center(child: Text('履歴データがありません'));
    }

    final labels = logs.map((e) => e.label).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('履歴', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.large),
        HistoryLineChart(
          title: '🌡 温度',
          unit: '℃',
          color: AppColors.warning,
          labels: labels,
          values: logs.map((e) => e.temperature).toList(),
        ),
        const SizedBox(height: AppSpacing.medium),
        HistoryLineChart(
          title: '💧 湿度',
          unit: '%',
          color: AppColors.info,
          labels: labels,
          values: logs.map((e) => e.humidity).toList(),
        ),
        const SizedBox(height: AppSpacing.medium),
        HistoryLineChart(
          title: '🪴 土壌水分',
          unit: '%',
          color: AppColors.primary,
          labels: labels,
          values: logs.map((e) => e.soilMoisture).toList(),
        ),
        const SizedBox(height: AppSpacing.medium),
        HistoryLineChart(
          title: '☀️ 照度',
          unit: ' lx',
          color: AppColors.accent,
          labels: labels,
          values: logs.map((e) => e.illuminance).toList(),
        ),
      ],
    );
  }
}
