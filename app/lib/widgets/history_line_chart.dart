import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// 履歴画面で使う、1項目分の推移を表示するカード。
/// [labels]は各データ点のX軸ラベル(日付など)、[values]は対応する数値。
class HistoryLineChart extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final List<String> labels;
  final List<double> values;

  const HistoryLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.color,
    required this.labels,
    required this.values,
  });

  static String _formatValue(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  /// 与えられた値に近い「見やすい」目盛り間隔(1 / 2 / 5 / 10のいずれかを
  /// 10のべき乗倍したもの)に丸める。
  /// 例: 6.7 → 5、23 → 20、0.42 → 0.5 のように、人が読みやすい間隔にする。
  static double _niceInterval(double rawInterval) {
    if (rawInterval <= 0) return 1;
    final exponent = (math.log(rawInterval) / math.ln10).floor();
    final magnitude = math.pow(10, exponent).toDouble();
    final residual = rawInterval / magnitude; // 1.0 〜 10.0の範囲になる

    double niceResidual;
    if (residual < 1.5) {
      niceResidual = 1;
    } else if (residual < 3) {
      niceResidual = 2;
    } else if (residual < 7) {
      niceResidual = 5;
    } else {
      niceResidual = 10;
    }
    return niceResidual * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final rawRange = (rawMax - rawMin).abs();
    // 全データが同一の値の場合、範囲がゼロだと目盛りが作れないため
    // 値の大きさに応じた最低限の範囲を確保する(0の場合はさらに1をフォールバック)。
    final safeRange = rawRange > 0 ? rawRange : (rawMax.abs() * 0.1).clamp(1, double.infinity);

    // 目盛り数の目安(3分割)を基準に、見やすい間隔(1/2/5/10系)へ丸める。
    // これにより「32.3」「29.1」のような半端な数値ではなく、
    // 「30」「32」のようなきれいな数値が目盛りに並ぶようになる。
    final gridInterval = _niceInterval(safeRange / 3);

    // 軸の上下端もgridIntervalの倍数に揃えることで、目盛りの数値自体を
    // きれいな値にする(データの実際の最小/最大よりわずかに広い範囲になる)。
    final minY = (rawMin / gridInterval).floor() * gridInterval;
    final maxY = (rawMax / gridInterval).ceil() * gridInterval;
    // 上下に1目盛り分の余白を持たせて、線がカードの端に張り付かないようにする
    // (gridIntervalの倍数のまま増減させるので、目盛りの値は崩れない)。
    final displayMinY = minY - gridInterval;
    final displayMaxY = maxY + gridInterval;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${_formatValue(values.last)}$unit',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: displayMinY,
                  maxY: displayMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: gridInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatValue(value),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              labels[index],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: color.withValues(alpha: 0.4),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 5,
                                  color: color,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                          ),
                        );
                      }).toList();
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.white,
                      tooltipBorder: BorderSide(
                        color: color.withValues(alpha: 0.5),
                      ),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => spots.map((spot) {
                        return LineTooltipItem(
                          '${_formatValue(spot.y)}$unit',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      // 通常時は各データ点にドットを常時表示しない
                      // (間引き後でも点数が多いと線が点の集まりに見えてしまうため)。
                      // タップした点だけ、上のlineTouchDataのgetTouchedSpotIndicatorで
                      // ドットを表示する。
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
