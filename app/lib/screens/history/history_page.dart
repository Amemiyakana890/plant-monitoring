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

  // 項目タブ(主軸:何を見るか)。期間タブ(従属:いつを見るか)と分けて、
  // 一度に選べるのはどちらか片方の折れ線グラフだけにする
  // (4項目を同時に縦積みしていた従来レイアウトからの変更)。
  // 並び順・ラベルはホーム画面(plant_card.dart)と揃えている
  // (温度→湿度→土壌水分→光量。「照度」ではなくホームと同じ「光量」表記)。
  static const List<_MetricOption> _metricOptions = [
    _MetricOption(
      key: 'temperature',
      label: '温度',
      unit: '℃',
      color: AppColors.warning,
      valueOf: _temperatureValue,
    ),
    _MetricOption(
      key: 'humidity',
      label: '湿度',
      unit: '%',
      color: AppColors.info,
      valueOf: _humidityValue,
    ),
    _MetricOption(
      key: 'soil',
      label: '土壌水分',
      unit: '%',
      color: AppColors.primary,
      valueOf: _soilValue,
    ),
    _MetricOption(
      key: 'illuminance',
      label: '光量',
      unit: ' lx',
      color: AppColors.accent,
      valueOf: _illuminanceValue,
    ),
  ];

  static double _soilValue(EnvironmentLog e) => e.soilMoisture;
  static double _temperatureValue(EnvironmentLog e) => e.temperature;
  static double _humidityValue(EnvironmentLog e) => e.humidity;
  static double _illuminanceValue(EnvironmentLog e) => e.illuminance;

  bool _requested = false;
  String _range = '24h';
  // タブの先頭(温度)を初期選択にする(並び順と揃えたほうが自然なため)。
  String _metricKey = 'temperature';

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

  void _onMetricSelected(String key) {
    if (key == _metricKey) return;
    setState(() => _metricKey = key);
  }

  /// [logs]の各データ点をグラフのX座標に変換する。
  /// 「先頭データ点からの経過時間」(時間単位のdouble)を使うことで、
  /// データ点の間隔(何番目かというインデックス)ではなく実際の経過時間が
  /// そのままグラフ上の横方向の間隔に反映されるようにする。
  ///
  /// 以前はインデックスをそのままX座標に使っていたため、デバイスの
  /// オン/オフなどでデータが疎になった時間帯があっても、グラフ上は
  /// 隣のデータ点と均等な間隔に詰めて描画されてしまっていた。
  List<double> _chartXValues(List<EnvironmentLog> logs) {
    if (logs.isEmpty) return const [];
    final base = logs.first.timestamp;
    return [
      for (final log in logs) log.timestamp.difference(base).inSeconds / 3600.0,
    ];
  }

  /// X軸のラベルを、選択中の[range]に応じて「実際の時刻をもとにした
  /// 理想的な等間隔の目盛り時刻」を先に決め、それぞれに最も近い実データ点へ
  /// 割り当てる方式で組み立てる。
  ///
  /// - 24h: 3時間ごとの壁時計上の区切り(00:00 / 03:00 / 06:00 …)を理想時刻
  ///   とし、表示範囲に含まれるものだけを対象にする。
  /// - 7d / 30d: 表示期間全体を最大[_maxDateLabels]個に均等分割した理想時刻
  ///   を対象にする。
  ///
  /// 以前は「データ点の何番目かで区切りが変わった瞬間」にラベルを置いて
  /// いたため、デバイスをオン/オフした前後でデータが疎になる区間があると、
  /// その前後のわずかなインデックス差の中で複数の区切りをまたいでしまい、
  /// ラベルが密集して重なって表示される問題があった。理想時刻→最近傍点、
  /// という組み立て方に変えることで、ラベルは実時間として本当に等間隔になり、
  /// 密集も起きにくくなる。
  Map<int, String> _chartLabels(
    List<EnvironmentLog> logs,
    List<double> xValues,
    String range,
  ) {
    if (logs.isEmpty) return const {};

    if (range == '24h') {
      final idealTimes = _threeHourBoundaries(
        logs.first.timestamp,
        logs.last.timestamp,
      );
      return _nearestPointLabels(
        logs: logs,
        xValues: xValues,
        idealTimes: idealTimes,
        // 実データ点の細かい時刻ではなく、区切りの時刻そのもの
        // (00:00, 03:00 …)を表示することで、ラベルがきれいな値になる。
        formatOf: (idealTime, actualTime) =>
            '${_twoDigits(idealTime.hour)}:${_twoDigits(idealTime.minute)}',
      );
    }

    final idealTimes = _evenlySpacedTimes(
      logs.first.timestamp,
      logs.last.timestamp,
      _maxDateLabels,
    );
    return _nearestPointLabels(
      logs: logs,
      xValues: xValues,
      idealTimes: idealTimes,
      // 日付ラベルは、区切り時刻そのものではなく実際に一番近いデータ点の
      // 日付を表示する(区切り時刻自体はグラフ上に存在しない架空の時刻の
      // ため、実データの日付の方が自然)。
      formatOf: (idealTime, actualTime) =>
          '${actualTime.month}/${actualTime.day}',
    );
  }

  /// X軸に表示するラベルの最大個数(7d/30dで使用)。
  static const int _maxDateLabels = 6;

  /// [start]〜[end]の範囲に含まれる、3時間おきの壁時計上の区切り時刻
  /// (00:00, 03:00, 06:00 …)を列挙する。
  List<DateTime> _threeHourBoundaries(DateTime start, DateTime end) {
    var boundary = DateTime(
      start.year,
      start.month,
      start.day,
      (start.hour ~/ 3) * 3,
    );
    while (boundary.isBefore(start)) {
      boundary = boundary.add(const Duration(hours: 3));
    }
    final boundaries = <DateTime>[];
    while (!boundary.isAfter(end)) {
      boundaries.add(boundary);
      boundary = boundary.add(const Duration(hours: 3));
    }
    return boundaries;
  }

  /// [start]〜[end]を[count]個に均等分割した時刻を列挙する
  /// ([start]と[end]自身を含む)。
  List<DateTime> _evenlySpacedTimes(DateTime start, DateTime end, int count) {
    final totalMicroseconds = end.difference(start).inMicroseconds;
    if (totalMicroseconds <= 0 || count <= 1) return [start];
    return [
      for (var k = 0; k < count; k++)
        start.add(
          Duration(
            microseconds: (totalMicroseconds * (k / (count - 1))).round(),
          ),
        ),
    ];
  }

  /// [idealTimes]それぞれについて、[logs]の中から時刻が最も近いデータ点を
  /// 探し、その点のX座標(小数を丸めた整数値)にラベルを割り当てる。
  /// 複数の理想時刻が同じ実データ点に最も近くなった場合は、同じキーになる
  /// ため自然に1つへ統合される(密集の再発防止)。
  Map<int, String> _nearestPointLabels({
    required List<EnvironmentLog> logs,
    required List<double> xValues,
    required List<DateTime> idealTimes,
    required String Function(DateTime idealTime, DateTime actualTime) formatOf,
  }) {
    final result = <int, String>{};
    for (final idealTime in idealTimes) {
      var nearestIndex = 0;
      var nearestDiff = logs[0].timestamp.difference(idealTime).abs();
      for (var i = 1; i < logs.length; i++) {
        final diff = logs[i].timestamp.difference(idealTime).abs();
        if (diff < nearestDiff) {
          nearestDiff = diff;
          nearestIndex = i;
        }
      }
      final key = xValues[nearestIndex].round();
      result[key] = formatOf(idealTime, logs[nearestIndex].timestamp);
    }
    return result;
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final store = PlantStoreScope.of(context);
    final logs = store.history;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('履歴', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.medium),
        // 項目タブ(主軸)。期間タブは各グラフの見出し内に小さく従属させる
        // (下の_buildSingleChart内、HistoryLineChart.trailingHeader)ため、
        // ここでは「何を見るか」だけを選ばせる。
        _MetricSelector(
          options: _metricOptions,
          selected: _metricKey,
          onChanged: _onMetricSelected,
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
          ..._buildSingleChart(logs),
      ],
    );
  }

  /// 生ログの点数が多い(24h/7d/30dで数百〜数千件になりうる)と、
  /// グラフが点・線で埋め尽くされて見づらくなるため、表示前に
  /// 最大[maxPoints]件程度まで間引く。
  /// 連続する数件を1つのグループにまとめ、各項目の平均値を取る
  /// (簡易的なダウンサンプリング。区間内の最初の点のtimestampを代表値として使う)。
  List<EnvironmentLog> _downsample(
    List<EnvironmentLog> logs, {
    int maxPoints = 60,
  }) {
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

  /// 選択中の項目タブ([_metricKey])1つ分の折れ線グラフと、
  /// その下に直近の実測値一覧を表示する。
  /// 期間セレクター(24h/7d/30d)はグラフの見出し内に小さく添えるだけにし、
  /// 項目タブと縦に2段並ぶことによる圧迫感を避ける。
  List<Widget> _buildSingleChart(List<EnvironmentLog> rawLogs) {
    final logs = _downsampleCached(rawLogs);
    final xValues = _chartXValues(logs);
    final xLabels = _chartLabels(logs, xValues, _range);
    final metric = _metricOptions.firstWhere((m) => m.key == _metricKey);

    return [
      HistoryLineChart(
        title: metric.label,
        unit: metric.unit,
        color: metric.color,
        xValues: xValues,
        xLabels: xLabels,
        values: logs.map(metric.valueOf).toList(),
        trailingHeader: _RangeSelector(
          options: _rangeOptions,
          selected: _range,
          onChanged: _onRangeSelected,
          compact: true,
        ),
      ),
      const SizedBox(height: AppSpacing.medium),
      _EnvironmentDataList(logs: _latestRawLogs(rawLogs)),
    ];
  }

  /// 環境データ一覧に表示する直近の実測値。ダウンサンプリング前の
  /// 生ログから、新しい順に最大[count]件を取り出す
  /// (グラフは間引き後の傾向を見るためのもの、一覧は「今の実測値」を
  /// そのまま確認するためのもの、と役割を分けているため)。
  List<EnvironmentLog> _latestRawLogs(
    List<EnvironmentLog> rawLogs, {
    int count = 3,
  }) {
    if (rawLogs.isEmpty) return const [];
    final sorted = [...rawLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(count).toList();
  }
}

/// 項目(土壌水分/温度/湿度/照度)1つ分の設定。
class _MetricOption {
  final String key;
  final String label;
  final String unit;
  final Color color;
  final double Function(EnvironmentLog log) valueOf;

  const _MetricOption({
    required this.key,
    required this.label,
    required this.unit,
    required this.color,
    required this.valueOf,
  });
}

/// 項目タブ(主タブ)。折れ線グラフでどの項目を見るかを選ぶ、
/// 履歴画面でいちばん優先度の高い切り替えなので、大きめのピルで表示する。
class _MetricSelector extends StatelessWidget {
  final List<_MetricOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _MetricSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.extraSmall),
              child: _buildPill(option),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(_MetricOption option) {
    final isSelected = option.key == selected;
    return GestureDetector(
      onTap: () => onChanged(option.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          option.label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 直近の実測値をそのままリスト表示するカード。
/// グラフ(傾向を見る)と役割を分け、「今の数値」を安心して確認できるように。
class _EnvironmentDataList extends StatelessWidget {
  final List<EnvironmentLog> logs;

  const _EnvironmentDataList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    // ダークモードでは固定の濃いグレー(AppColors.textPrimary)だと
    // 背景に沈んで読めなくなるため、テーマの本文色をベースに薄める
    // (HistoryLineChartの軸ラベルと同じ考え方)。
    final mutedColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final valueStyle = Theme.of(context).textTheme.bodyMedium;
    final dotStyle = valueStyle?.copyWith(color: mutedColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('環境データ一覧', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.small),
            for (var i = 0; i < logs.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.large),
              // 日付・時刻は1行目に単独で表示し、4項目の数値は2行目で
              // Wrap(画面幅に収まらなければ自動で折り返す)にする。
              // 以前は1本のRowに全部並べていたため、画面幅が狭い環境
              // (Web版など)や光量が3桁になるケースで右端がはみ出していた。
              _EnvironmentLogRow(
                log: logs[i],
                mutedColor: mutedColor,
                valueStyle: valueStyle,
                dotStyle: dotStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// [_EnvironmentDataList]の1件分の行(日付1行目 + 数値をWrapで2行目)。
class _EnvironmentLogRow extends StatelessWidget {
  final EnvironmentLog log;
  final Color? mutedColor;
  final TextStyle? valueStyle;
  final TextStyle? dotStyle;

  const _EnvironmentLogRow({
    required this.log,
    required this.mutedColor,
    required this.valueStyle,
    required this.dotStyle,
  });

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _formatTimestamp(DateTime t) =>
      '${_twoDigits(t.month)}/${_twoDigits(t.day)} '
      '${_twoDigits(t.hour)}:${_twoDigits(t.minute)}';

  /// 項目ごとに区切った文字列のリストを返す。
  /// 従来は1本のRowに全部詰め込んで横幅オーバーフローの原因になっていたため、
  /// build側で[Wrap]に渡して画面幅に応じて折り返せるようにする。
  /// 並び順はホーム画面(plant_card.dart)と同じ:温度→湿度→土壌水分→光量。
  static List<String> _formatValues(EnvironmentLog log) {
    final temperature = log.temperature.toStringAsFixed(1);
    final humidity = log.humidity.round();
    final soil = log.soilMoisture.round();
    final illuminance = log.illuminance.round();
    return [
      '温度$temperature℃',
      '湿度$humidity%',
      '土壌$soil%',
      '光量${illuminance}lx',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final values = _formatValues(log);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatTimestamp(log.timestamp),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            for (var j = 0; j < values.length; j++) ...[
              if (j > 0) Text('・', style: dotStyle),
              Text(values[j], style: valueStyle),
            ],
          ],
        ),
      ],
    );
  }
}

/// 「24h / 7d / 30d」のピル型セグメントコントロール。
///
/// [compact]がtrueの場合、グラフ見出しに添える従属コントロールとして
/// 一回り小さく表示する(項目タブ[_MetricSelector]が主タブであるのに対し、
/// こちらは「いつを見るか」の補助コントロールという位置付けのため)。
class _RangeSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool compact;

  const _RangeSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: compact ? AppColors.background : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: compact
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (compact ? Colors.white : AppColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          option,
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            color: isSelected
                ? (compact ? AppColors.textPrimary : Colors.white)
                : AppColors.textPrimary.withValues(alpha: compact ? 0.5 : 1),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
