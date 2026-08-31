import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// 履歴画面で使う、1項目分の推移を表示するカード。
/// [xValues]は各データ点の実際の経過時間(先頭データ点からの経過時間、
/// 時間単位のdouble)、[values]は対応する数値。
/// [xLabels]はX軸に文字ラベルを表示する位置(=[xValues]を丸めた整数値)と
/// 表示文字列の対応表。
///
/// 以前は「データ点の何番目か(インデックス)」をそのままX座標として使い、
/// ラベルもインデックス位置に紐付けていた。これだとデバイスの再起動・
/// オフライン等でデータが疎になった時間帯があっても、隣り合うデータ点の
/// 間隔が実時間としては大きく離れているのにグラフ上では均等に詰めて
/// 描画されてしまい、その前後でラベルが密集して重なる問題があった。
/// 実際の経過時間をX座標に使うことで、データの空白期間はグラフ上でも
/// 正しく間延びして表現され、ラベルの位置も実時間ベースで自然に分散する。
class HistoryLineChart extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final List<double> xValues;
  final Map<int, String> xLabels;
  final List<double> values;

  /// タイトル行の下に右寄せで表示する補助コントロール
  /// (履歴画面では24h/7d/30dの期間セレクターを渡す想定)。
  /// 項目タブ(何を見るか)がこのカードの外側にある主タブなのに対し、
  /// こちらは「いつを見るか」の従属コントロールとして小さく添える。
  final Widget? trailingHeader;

  const HistoryLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.color,
    required this.xValues,
    required this.xLabels,
    required this.values,
    this.trailingHeader,
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
    final safeRange = rawRange > 0
        ? rawRange
        : (rawMax.abs() * 0.1).clamp(1, double.infinity);

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

    // 左右にも余白を持たせて、線やラベルがカードの端に張り付かないように
    // する(Y軸で1目盛り分の余白を持たせているのと同じ考え方)。
    // 等間隔ラベル([_evenlySpacedTimes]相当)は意図的に最初と最後の実データ
    // 時刻を含めているため、余白が無いとちょうどプロット領域の端にラベルが
    // 来てしまい、文字の後ろ半分が欠けたり隣接要素と重なって見えたりする
    // (実際にAndroid実機でラベルが詰まって見える不具合として報告された)。
    //
    // 余白の量は必ず「1時間の整数倍」にする。ラベル側([xLabels]・
    // bottomTitlesのinterval:1)は実時間(時間単位)を整数に丸めた値を
    // キーにして紐付けているため、余白を中途半端な小数にすると目盛りの
    // 評価位置(0, 1, 2, …からの整数間隔)がずれてしまい、ラベルが
    // 正しい位置に出なくなる恐れがある。
    final rawMinX = xValues.first;
    final rawMaxX = xValues.last;
    final xSpan = rawMaxX - rawMinX;
    final xMarginHours = math.max(1, (xSpan * 0.04).round());
    final displayMinX = rawMinX - xMarginHours;
    final displayMaxX = rawMaxX + xMarginHours;

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
            if (trailingHeader != null) ...[
              const SizedBox(height: AppSpacing.extraSmall),
              Align(alignment: Alignment.centerRight, child: trailingHeader),
            ],
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minX: displayMinX,
                  maxX: displayMaxX,
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
                        // 実時間(時間単位)の軸に対して1時間刻みで評価し、
                        // xLabelsに登録されている位置(=ラベルを表示したい
                        // 実データ点に最も近い整数値)にだけ文字を出す。
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final text = xLabels[value.round()];
                          if (text == null || text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              text,
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
                          FlSpot(xValues[i], values[i]),
                      ],
                      // X軸が実際の経過時間(データの疎密によって間隔が
                      // 不均等になりうる)になったため、滑らかな曲線補間
                      // (isCurved: true)は使わない。間隔が不揃いな点同士を
                      // スプライン補間すると、実データにない位置まで曲線が
                      // 膨らんだりへこんだりするオーバーシュートが起きて
                      // グラフの形が崩れて見えるため、直線で点を結ぶ。
                      isCurved: false,
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
