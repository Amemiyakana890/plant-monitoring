import 'package:flutter/material.dart';

import '../../models/environment_log.dart';
import '../../state/plant_store_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/history_line_chart.dart';

/// 過去の環境データをグラフで確認する画面。
/// データは[PlantStore]経由で取得する(設計書5-5 GET /history/:plantId 相当)。
/// 24h / 7d / 30d の切り替えができ、選択したrangeを[PlantStore.loadHistory]
/// に渡して再取得する。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const List<String> _rangeOptions = ['24h', '7d', '30d'];

  bool _requested = false;
  String _range = '24h';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回表示時にまだ履歴を取得していなければ取得する。
    if (_requested) return;
    _requested = true;
    final store = PlantStoreScope.of(context);
    if (store.history.isEmpty && !store.isLoadingHistory) {
      store.loadHistory(range: _range);
    }
  }

  void _onRangeSelected(String range) {
    if (range == _range) return;
    setState(() => _range = range);
    PlantStoreScope.of(context).loadHistory(range: range);
  }

  /// [logs]の各データ点に対応するX軸ラベルを、選択中の[range]に応じて
  /// 実際の日時([EnvironmentLog.timestamp])から組み立てる。
  ///
  /// - 24h: 3時間ごとの区切り(00:00 / 03:00 / 06:00 …)の最初の点にだけ
  ///   "HH:mm" を表示し、それ以外は空文字にする。
  /// - 7d / 30d: 日付が変わる境界(0時)の最初の点にだけ "M/d" を表示する。
  ///
  /// データ点の間隔そのものに依存せず「境界をまたいだかどうか」で
  /// 判定しているため、間隔が変わっても区切りの見え方は崩れない。
  List<String> _labelsFor(List<EnvironmentLog> logs, String range) {
    if (range == '24h') {
      return _boundaryLabels(
        logs,
        bucketKeyOf: (t) => DateTime(t.year, t.month, t.day, (t.hour ~/ 3) * 3),
        formatOf: (bucketStart) =>
            '${_twoDigits(bucketStart.hour)}:${_twoDigits(bucketStart.minute)}',
      );
    }
    return _boundaryLabels(
      logs,
      bucketKeyOf: (t) => DateTime(t.year, t.month, t.day),
      formatOf: (bucketStart) => '${bucketStart.month}/${bucketStart.day}',
    );
  }

  List<String> _boundaryLabels(
    List<EnvironmentLog> logs, {
    required DateTime Function(DateTime timestamp) bucketKeyOf,
    required String Function(DateTime bucketStart) formatOf,
  }) {
    final labels = <String>[];
    DateTime? lastBucket;
    for (final log in logs) {
      final bucket = bucketKeyOf(log.timestamp);
      if (bucket != lastBucket) {
        labels.add(formatOf(bucket));
        lastBucket = bucket;
      } else {
        labels.add('');
      }
    }
    return labels;
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final logs = store.history;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('履歴', style: Theme.of(context).textTheme.headlineLarge),
            _RangeSelector(
              options: _rangeOptions,
              selected: _range,
              onChanged: _onRangeSelected,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.large),
        if (store.isLoadingHistory && logs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.large),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (store.historyErrorMessage != null && logs.isEmpty)
          Column(
            children: [
              Text(store.historyErrorMessage!),
              const SizedBox(height: AppSpacing.small),
              OutlinedButton(
                onPressed: () => store.loadHistory(range: _range),
                child: const Text('再読み込み'),
              ),
            ],
          )
        else if (logs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.large),
            child: Center(child: Text('履歴データがありません')),
          )
        else
          ..._buildCharts(logs),
      ],
    );
  }

  List<Widget> _buildCharts(List<EnvironmentLog> logs) {
    final labels = _labelsFor(logs, _range);
    return [
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
    ];
  }
}

/// 「24h / 7d / 30d」のピル型セグメントコントロール。
class _RangeSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RangeSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final option in options) _buildSegment(option)],
      ),
    );
  }

  Widget _buildSegment(String option) {
    final isSelected = option == selected;
    return GestureDetector(
      onTap: () => onChanged(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          option,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
