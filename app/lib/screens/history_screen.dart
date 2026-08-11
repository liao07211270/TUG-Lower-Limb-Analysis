import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../tug_phase_display.dart'; // 🌟 引入資料庫小幫手 (請確認路徑是否正確)

// ==========================================
// 1. 嚴格遵守 UI 靈感圖的 5 色調色盤
// ==========================================
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color accentBlue = Color(0xFFABD7FB);
const Color accentPeach = Color(0xFFFCCEB4);

const Color textDark = Color(0xFF4A4A4A);
const Color textLight = Color(0xFF9E9E9E);

// ==========================================
// 2. 共用工具：顯示精緻化詳細紀錄彈窗 (🌟 已升級為 6 階段)
// ==========================================
/// 單一橫向時間軸：由左至右為起立→去程→轉向→回程→轉身→坐下，寬度比例為各階段秒數。
Widget buildPhaseTimelineSingleBar(Map<String, dynamic> record) {
  final d = TugSixPhaseDurations.fromRecord(record);
  final phases = d.toTimelineSegments().map((s) => (s.name, s.duration, s.color)).toList();

  final sum = phases.fold<double>(0, (a, p) => a + p.$2);
  if (sum <= 0) {
    return const SizedBox(height: 12);
  }

  int flexFor(double sec) => math.max(1, (sec * 1000).round());

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 22,
        child: Row(
          children:
              phases.map((p) {
                if (p.$2 <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: flexFor(p.$2),
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: p.$3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        children:
            phases.where((p) => p.$2 > 0).map((p) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${p.$1} ${p.$2.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    ],
  );
}

double _recordSeconds(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

Widget _buildPhaseAnalysisRows(Map<String, dynamic> record) {
  final durations = TugSixPhaseDurations.fromRecord(record);
  final phases = <({String name, double duration, Color color, IconData icon})>[
    (
      name: '起立',
      duration: durations.standUp,
      color: accentPeach,
      icon: Icons.accessibility_new_rounded,
    ),
    (
      name: '去程',
      duration: durations.walkGo,
      color: accentBlue,
      icon: Icons.directions_walk_rounded,
    ),
    (
      name: '轉身',
      duration: durations.turn1 + durations.turn2,
      color: accentGreen,
      icon: Icons.sync_rounded,
    ),
    (
      name: '回程',
      duration: durations.walkReturn,
      color: accentBlue,
      icon: Icons.directions_walk_rounded,
    ),
    (
      name: '坐下',
      duration: durations.sitDown,
      color: primaryOrange,
      icon: Icons.event_seat_rounded,
    ),
  ];
  final maxPhaseSeconds = phases.fold<double>(
    0,
    (maxValue, phase) => math.max(maxValue, phase.duration),
  );

  return Column(
    children: List.generate(phases.length, (index) {
      final phase = phases[index];
      final progress =
          maxPhaseSeconds <= 0
              ? 0.0
              : (phase.duration / maxPhaseSeconds).clamp(0.0, 1.0);

      return Padding(
        padding: EdgeInsets.only(bottom: index == phases.length - 1 ? 0 : 14),
        child: Row(
          children: [
            Icon(phase.icon, size: 16, color: phase.color),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text(
                phase.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 12,
                  color: bgCream,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: phase.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(
                '${phase.duration.toStringAsFixed(1)}s',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

void showRecordDetailsBottomSheet(
  BuildContext context,
  Map<String, dynamic> record,
) {
  String formatDateHeader(dynamic raw) {
    final DateTime date =
        raw is DateTime
            ? raw
            : (DateTime.tryParse(raw.toString()) ?? DateTime.now());
    return "${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日";
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '測試詳細報告',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentPeach.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatDateHeader(record['date']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: bgCream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TUG 總耗時',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _recordSeconds(record['totalTime']).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '秒',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '階段數據分析',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildPhaseAnalysisRows(record),
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      );
    },
  );
}

// ==========================================
// 3. 主頁面：歷史趨勢分析
// ==========================================
class HistoryScreen extends StatefulWidget {
  final int userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // 🌟 將變數名稱保留，但內容會從 SQLite 撈取
  List<Map<String, dynamic>> _mockHistoryData = [];
  bool _isLoading = true;
  final ScrollController _trendChartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRealData(); // 🌟 啟動時撈取真資料
  }

  @override
  void dispose() {
    _trendChartScrollController.dispose();
    super.dispose();
  }

  // 🌟 從 SQLite 撈取資料並轉換為 UI 需要的格式
  Future<void> _loadRealData() async {
    final dbData = await DatabaseHelper.instance.getHistoryForUser(
      widget.userId,
    );
    List<Map<String, dynamic>> parsedData = [];
    final DateFormat chineseFmt = DateFormat('yyyy年MM月dd日');

    for (var row in dbData) {
      DateTime parsedDate;
      final rawDate = row['date'];
      final iso = DateTime.tryParse(rawDate?.toString() ?? '');
      if (iso != null) {
        parsedDate = iso;
      } else {
        try {
          parsedDate = chineseFmt.parse(rawDate.toString());
        } catch (_) {
          parsedDate = DateTime.now();
        }
      }

      parsedData.add({
        'id': row['id'].toString(),
        'date': parsedDate,
        'totalTime': row['total_time'],
        'standUp': row['stand_up'],
        'walkGo': row['walk_go'],
        'turn1': row['turn1'],
        'walkReturn': row['walk_return'],
        'turn2': row['turn2'],
        'sitDown': row['sit_down'],
      });
    }

    setState(() {
      _mockHistoryData = parsedData; // 存入列表
      _isLoading = false;
    });
    _scrollTrendChartToLatest();
  }

  void _scrollTrendChartToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_trendChartScrollController.hasClients) return;
      _trendChartScrollController.jumpTo(
        _trendChartScrollController.position.maxScrollExtent,
      );
    });
  }

  // 🌟 呼叫 SQLite 真實刪除
  Future<void> _deleteRecord(String id) async {
    await DatabaseHelper.instance.deleteHistory(int.parse(id));
    _loadRealData(); // 刪除後重新載入畫面
  }

  String _formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Widget _buildPhaseLegend() {
    final sample = TugSixPhaseDurations(
      standUp: 1,
      walkGo: 1,
      turn1: 1,
      walkReturn: 1,
      turn2: 1,
      sitDown: 1,
    ).toTimelineSegments();

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children:
          sample.map((phase) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: phase.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  phase.name,
                  style: const TextStyle(
                    color: textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildPhaseStackedBarChart(List<Map<String, dynamic>> chartData) {
    final maxTotal = chartData.fold<double>(
      0,
      (maxValue, record) => math.max(maxValue, _asDouble(record['totalTime'])),
    );
    final double maxY = math.max(1.0, maxTotal * 1.15);
    const double yAxisWidth = 34;
    const double bottomTitleHeight = 42;
    final double yInterval = maxY <= 12 ? 2 : 5;
    final yLabelValues = <double>[
      for (double value = 0; value <= maxY; value += yInterval) value,
    ];

    FlTitlesData titlesData({required bool showBottomTitles}) {
      return FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: bottomTitleHeight,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= chartData.length) {
                return const SizedBox.shrink();
              }
              final date = chartData[index]['date'] as DateTime;
              return showBottomTitles
                  ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  : const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    Widget fixedYAxis() {
      return SizedBox(
        width: yAxisWidth,
        child: LayoutBuilder(
          builder: (context, axisConstraints) {
            final plotHeight = math.max(
              0.0,
              axisConstraints.maxHeight - bottomTitleHeight,
            );
            const labelHeight = 14.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: bottomTitleHeight),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final value in yLabelValues)
                    Positioned(
                      left: 0,
                      right: 4,
                      bottom:
                          ((value / maxY) * (plotHeight - labelHeight)).clamp(
                            0.0,
                            math.max(0.0, plotHeight - labelHeight),
                          ),
                      child: SizedBox(
                        height: labelHeight,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${value.toInt()}s',
                            style: const TextStyle(
                              color: textLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollAreaWidth = math.max(0.0, constraints.maxWidth - yAxisWidth);
        final chartWidth = math.max(
          scrollAreaWidth,
          chartData.length * 34.0,
        );
        final barWidth = chartData.length > 12 ? 10.0 : 16.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fixedYAxis(),
            Expanded(
              child: Scrollbar(
                controller: _trendChartScrollController,
                thumbVisibility: chartWidth > scrollAreaWidth,
                child: SingleChildScrollView(
                  controller: _trendChartScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BarChart(
                          BarChartData(
                            minY: 0,
                            maxY: maxY,
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(enabled: false),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: yInterval,
                              getDrawingHorizontalLine:
                                  (value) => FlLine(
                                    color: bgCream,
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                  ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: titlesData(showBottomTitles: true),
                            barGroups: List.generate(chartData.length, (index) {
                              final record = chartData[index];
                              final phases =
                                  TugSixPhaseDurations.fromRecord(record)
                                      .toTimelineSegments();
                              double start = 0;
                              final stacks = <BarChartRodStackItem>[];
                              for (final phase in phases) {
                                if (phase.duration <= 0) continue;
                                final end = start + phase.duration;
                                stacks.add(
                                  BarChartRodStackItem(
                                    start,
                                    end,
                                    phase.color,
                                  ),
                                );
                                start = end;
                              }
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: math.max(start, 0.01),
                                    width: barWidth,
                                    borderRadius: BorderRadius.circular(4),
                                    rodStackItems: stacks,
                                    color: bgCream,
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                        LineChart(
                          LineChartData(
                            minX: -0.5,
                            maxX: chartData.length - 0.5,
                            minY: 0,
                            maxY: maxY,
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor:
                                    (_) => textDark.withOpacity(0.9),
                                getTooltipItems: (spots) {
                                  return spots.map((spot) {
                                    final index = spot.x.round().clamp(
                                      0,
                                      chartData.length - 1,
                                    );
                                    final date =
                                        chartData[index]['date'] as DateTime;
                                    return LineTooltipItem(
                                      '${date.month}/${date.day}\n${spot.y.toStringAsFixed(2)} 秒',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: titlesData(showBottomTitles: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  chartData.length,
                                  (index) => FlSpot(
                                    index.toDouble(),
                                    _asDouble(chartData[index]['totalTime']),
                                  ),
                                ),
                                isCurved: true,
                                curveSmoothness: 0.25,
                                color: accentBlue,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) =>
                                          FlDotCirclePainter(
                                            radius: 4.5,
                                            color: Colors.white,
                                            strokeWidth: 3,
                                            strokeColor: accentBlue,
                                          ),
                                ),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryOrange,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('您選擇了搜尋：${picked.year}/${_formatDate(picked)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgCream,
        body: Center(child: CircularProgressIndicator(color: primaryOrange)),
      );
    }

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentRecords =
        _mockHistoryData
            .where((r) => (r['date'] as DateTime).isAfter(thirtyDaysAgo))
            .toList();
    // 讓圖表由左到右顯示舊到新
    final List<Map<String, dynamic>> chartData = recentRecords.reversed.toList();

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        title: const Text(
          '歷史趨勢分析',
          style: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. 頂部：天空藍趨勢圖表
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '近一個月總耗時',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (chartData.isEmpty)
                      const SizedBox(
                        height: 180,
                        child: Center(
                          child: Text(
                            '近一個月無資料',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        '堆疊長條為各階段耗時，折線為總耗時',
                        style: TextStyle(
                          color: textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        child: _buildPhaseStackedBarChart(chartData),
                      ),
                      const SizedBox(height: 10),
                      _buildPhaseLegend(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. 標題與搜尋
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '近期測試',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                  ),
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentPeach.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: primaryOrange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '選擇日期',
                            style: TextStyle(
                              color: primaryOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 近期紀錄列表
          recentRecords.isEmpty
              ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      '近一個月尚無測試紀錄',
                      style: TextStyle(color: textLight),
                    ),
                  ),
                ),
              )
              : SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final record = recentRecords[index];
                    final date = record['date'] as DateTime;
                    return Dismissible(
                      key: Key(record['id']),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text(
                                '確認刪除',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              content: Text(
                                '確定要刪除 ${date.month}/${date.day} 的測試紀錄嗎？\n此動作無法復原。',
                                style: const TextStyle(color: textLight),
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text(
                                    '取消',
                                    style: TextStyle(color: textLight),
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text(
                                    '刪除',
                                    style: TextStyle(
                                      color: primaryOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) => _deleteRecord(record['id']),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: primaryOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      child: GestureDetector(
                        onTap:
                            () => showRecordDetailsBottomSheet(context, record),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryOrange.withOpacity(0.03),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: accentPeach.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_walk_rounded,
                                  color: primaryOrange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${date.year}年${date.month}月${date.day}日',
                                      style: const TextStyle(
                                        color: textLight,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'TUG 步態檢測',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _recordSeconds(
                                      record['totalTime'],
                                    ).toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Text(
                                    's',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: recentRecords.length),
                ),
              ),

          // 4. 查看所有紀錄按鈕
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: InkWell(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AllRecordsScreen(allRecords: _mockHistoryData),
                      ),
                    ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.format_list_bulleted_rounded,
                        color: Colors.green[800],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '查看所有歷史紀錄',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 獨立頁面：查看所有紀錄
// ==========================================
class AllRecordsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> allRecords;

  const AllRecordsScreen({super.key, required this.allRecords});

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedRecords = {};
    for (var record in allRecords) {
      final date = record['date'] as DateTime;
      final monthKey =
          "${date.year}年 ${date.month.toString().padLeft(2, '0')}月";
      if (!groupedRecords.containsKey(monthKey)) groupedRecords[monthKey] = [];
      groupedRecords[monthKey]!.add(record);
    }

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primaryOrange.withOpacity(0.1), blurRadius: 4),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: textDark,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '所有紀錄',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: groupedRecords.keys.length,
        itemBuilder: (context, index) {
          String monthKey = groupedRecords.keys.elementAt(index);
          List<Map<String, dynamic>> monthData = groupedRecords[monthKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: primaryOrange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      monthKey,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textLight,
                      ),
                    ),
                  ],
                ),
              ),
              ...monthData
                  .map((record) => _buildPremiumSimpleCard(context, record))
                  .toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumSimpleCard(
    BuildContext context,
    Map<String, dynamic> record,
  ) {
    final date = record['date'] as DateTime;
    final dateStr =
        "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: () => showRecordDetailsBottomSheet(context, record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentPeach.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  color: textLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${record['totalTime'].toStringAsFixed(2)}s',
                  style: const TextStyle(
                    fontSize: 16,
                    color: primaryOrange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bgCream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: primaryOrange,
                    size: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
