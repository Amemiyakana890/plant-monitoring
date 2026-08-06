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

  // 間引き結果のキャッシュ。
  // 「元データのリストが前回と同じ(参照が同一)」かつ「rangeが同じ」であれば、
  // build()が何度呼ばれても間引き処理(_downsample)を再実行しない。
  // 元データはPlantStore.loadHistory()が新しいListに置き換えるため、
  // 参照比較(identical)でデータ更新の有無を判定できる。
  List<EnvironmentLog>? _cachedRawLogs;
  String? _cachedRangeForDownsample;
  List<EnvironmentLog>? _cachedDownsampledLogs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回表示時にまだ履歴を取得していなければ取得する。
    if (_requested) return;
    _requested = true;

    // 注意: PlantStore.loadHistory()はnotifyListeners()を同期的に
    // (awaitの前に)呼び出す。didChangeDependencies()はウィジェットツリーの
    // 構築(ビルド)処理の途中で呼ばれるため、ここで直接呼び出すと
    // 「setState() or markNeedsBuild() called during build」エラーになる。
    // そのため、今のフレームの構築が完了した直後まで呼び出しを遅らせる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = PlantStoreScope.of(context);
      if (store.history.isEmpty && !store.isLoadingHistory) {
        store.loadHistory(range: _range);
      }
    });
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
  /// - 7d / 30d: 間引き後の点数に応じて均等な間隔(最大[_maxDateLabels]個)で
  ///   "M/d" を表示する。カレンダー上の「日付が変わる境界」ではなく、
  ///   表示する点の総数を基準に間隔を決めるため、30dのように期間が長く
  ///   間引き後も日境界の数自体が多いケースでも、ラベルが詰まって
  ///   重ならないようにしている。
  List<String> _labelsFor(List<EnvironmentLog> logs, String range) {
    if (range == '24h') {
      return _boundaryLabels(
        logs,
        bucketKeyOf: (t) => DateTime(t.year, t.month, t.day, (t.hour ~/ 3) * 3),
        formatOf: (bucketStart) =>
            '${_twoDigits(bucketStart.hour)}:${_twoDigits(bucketStart.minute)}',
      );
    }
    return _evenlySpacedLabels(
      logs,
      formatOf: (t) => '${t.month}/${t.day}',
    );
  }

  /// X軸に表示するラベルの最大個数(7d/30dで使用)。
  /// これより多くの日境界があっても、この個数に収まるよう間隔を空けて表示する。
  static const int _maxDateLabels = 6;

  /// [logs]の点数に応じて、最大[_maxDateLabels]個になるよう均等な間隔で
  /// ラベルを配置する(それ以外の点は空文字にする)。
  List<String> _evenlySpacedLabels(
    List<EnvironmentLog> logs, {
    required String Function(DateTime timestamp) formatOf,
  }) {
    final labels = List<String>.filled(logs.length, '');
    if (logs.isEmpty) return labels;

    final step = (logs.length / _maxDateLabels).ceil().clamp(1, logs.length);
    for (var i = 0; i < logs.length; i += step) {
      labels[i] = formatOf(logs[i].timestamp);
    }
    return labels;
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

  /// 生ログの点数が多い(24h/7d/30dで数百〜数千件になりうる)と、
  /// グラフが点・線で埋め尽くされて見づらくなるため、表示前に
  /// 最大[maxPoints]件程度まで間引く。
  /// 連続する数件を1つのグループにまとめ、各項目の平均値を取る
  /// (簡易的なダウンサンプリング。区間内の最初の点のtimestampを代表値として使う)。
  List<EnvironmentLog> _downsample(List<EnvironmentLog> logs, {int maxPoints = 60}) {
    if (logs.length <= maxPoints) return logs;

    final bucketSize = (logs.length / maxPoints).ceil();
    final result = <EnvironmentLog>[];
    for (var i = 0; i < logs.length; i += bucketSize) {
      final end = (i + bucketSize).clamp(0, logs.length);
      result.add(_averageLog(logs.sublist(i, end)));
    }
    return result;
  }

  EnvironmentLog _averageLog(List<EnvironmentLog> bucket) {
    double average(double Function(EnvironmentLog log) select) =>
        bucket.map(select).reduce((a, b) => a + b) / bucket.length;

    return EnvironmentLog(
      timestamp: bucket.first.timestamp,
      label: bucket.first.label,
      temperature: average((e) => e.temperature),
      humidity: average((e) => e.humidity),
      soilMoisture: average((e) => e.soilMoisture),
      illuminance: average((e) => e.illuminance),
    );
  }

  /// [_downsample]の結果をキャッシュしつつ取得する。
  /// 元データ(リストの参照)とrangeがどちらも前回と同じであれば、
  /// 間引き処理を再実行せずキャッシュ済みの結果を返す。
  List<EnvironmentLog> _downsampleCached(List<EnvironmentLog> rawLogs) {
    if (_cachedDownsampledLogs != null &&
        identical(_cachedRawLogs, rawLogs) &&
        _cachedRangeForDownsample == _range) {
      return _cachedDownsampledLogs!;
    }

    final result = _downsample(rawLogs);
    _cachedRawLogs = rawLogs;
    _cachedRangeForDownsample = _range;
    _cachedDownsampledLogs = result;
    return result;
  }

  List<Widget> _buildCharts(List<EnvironmentLog> rawLogs) {
    final logs = _downsampleCached(rawLogs);
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
