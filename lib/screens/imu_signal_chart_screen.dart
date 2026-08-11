import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../imu_column_layout.dart';
import '../imu_series_storage.dart';
import '../tug_phase_display.dart';

const Color _bgCream = Color(0xFFF9F2EF);
const Color _primaryOrange = Color(0xFFF98C53);
const Color _textDark = Color(0xFF4A4A4A);
const Color _textLight = Color(0xFF9E9E9E);

/// 即時／上傳紀錄的 Acc/Gyro 時序圖（由結果頁「查看訊號圖」進入）。
class ImuSignalChartScreen extends StatefulWidget {
  final String? imuSeriesPath;
  final int? historyId;
  final double standUpTime;
  final double walkGoTime;
  final double turn1Time;
  final double walkReturnTime;
  final double turn2Time;
  final double sitDownTime;

  const ImuSignalChartScreen({
    super.key,
    this.imuSeriesPath,
    this.historyId,
    this.standUpTime = 0,
    this.walkGoTime = 0,
    this.turn1Time = 0,
    this.walkReturnTime = 0,
    this.turn2Time = 0,
    this.sitDownTime = 0,
  });

  @override
  State<ImuSignalChartScreen> createState() => _ImuSignalChartScreenState();
}

class _ImuSignalChartScreenState extends State<ImuSignalChartScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _partLabels = ['腰部', '左大腿', '右大腿', '左小腿', '右小腿'];

  late TabController _tabController;
  List<List<double>> _rows = [];
  double _sampleRateHz = 60;
  bool _loading = true;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _partLabels.length, vsync: this);
    _loadImuSeries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImuSeries() async {
    String? path = widget.imuSeriesPath;
    if (path == null && widget.historyId != null) {
      final row = await DatabaseHelper.instance.getHistoryById(
        widget.historyId!,
      );
      path = row?['imu_series_path'] as String?;
    }

    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasData = false;
        });
      }
      return;
    }

    final payload = await ImuSeriesStorage.loadFile(path);
    if (!mounted) return;

    if (payload == null) {
      setState(() {
        _loading = false;
        _hasData = false;
      });
      return;
    }

    final rawRows = payload['rows'];
    _sampleRateHz = (payload['sampleRateHz'] as num?)?.toDouble() ?? 60;
    if (rawRows is List) {
      _rows =
          rawRows
              .map((e) {
                if (e is! List) return <double>[];
                return e.map((v) => (v as num).toDouble()).toList();
              })
              .where((r) => r.length >= 63)
              .toList();
    }

    setState(() {
      _loading = false;
      _hasData = _rows.isNotEmpty;
    });
  }

  List<FlSpot> _spotsForAxis(int partIndex, int axisIndex, bool acc) {
    final start =
        ImuColumnLayout.rowStartForPart(_partLabels[partIndex]) ?? 1;
    final idx = acc ? start + axisIndex : start + 3 + axisIndex;
    final out = <FlSpot>[];
    for (int i = 0; i < _rows.length; i++) {
      if (idx >= _rows[i].length) continue;
      out.add(FlSpot(i / _sampleRateHz, _rows[i][idx]));
    }
    return out;
  }

  double get _chartMaxX {
    if (_rows.isEmpty) return 10;
    final dataEnd = _rows.length / _sampleRateHz;
    final phases = [
      widget.standUpTime,
      widget.walkGoTime,
      widget.turn1Time,
      widget.walkReturnTime,
      widget.turn2Time,
      widget.sitDownTime,
    ];
    var sum = 0.0;
    for (final p in phases) {
      sum += p > 0 ? p : 0;
    }
    return math.max(dataEnd, sum) * 1.02;
  }

  List<VerticalRangeAnnotation> _phaseVerticalRanges() {
    final phases = [
      widget.standUpTime,
      widget.walkGoTime,
      widget.turn1Time,
      widget.walkReturnTime,
      widget.turn2Time,
      widget.sitDownTime,
    ];
    var x0 = 0.0;
    final list = <VerticalRangeAnnotation>[];
    for (int i = 0; i < phases.length; i++) {
      final d = phases[i];
      if (d <= 0) continue;
      list.add(
        VerticalRangeAnnotation(
          x1: x0,
          x2: x0 + d,
          color: kTugSixPhaseColors[i].withOpacity(0.22),
        ),
      );
      x0 += d;
    }
    return list;
  }

  Widget _phaseTitleBar() {
    final phases = TugSixPhaseDurations(
      standUp: widget.standUpTime,
      walkGo: widget.walkGoTime,
      turn1: widget.turn1Time,
      walkReturn: widget.walkReturnTime,
      turn2: widget.turn2Time,
      sitDown: widget.sitDownTime,
    ).seconds;
    var sum = 0.0;
    for (final p in phases) {
      sum += p > 0 ? p : 0;
    }
    if (sum <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (int i = 0; i < phases.length; i++)
            if (phases[i] > 0)
              Expanded(
                flex: math.max(1, (phases[i] / sum * 1000).round()),
                child: Center(
                  child: Text(
                    kTugSixPhaseNames[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _textDark.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _signalChart({
    required String title,
    required double minY,
    required double maxY,
    required List<LineChartBarData> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _chartMaxX,
                minY: minY,
                maxY: maxY,
                rangeAnnotations: RangeAnnotations(
                  verticalRangeAnnotations: _phaseVerticalRanges(),
                ),
                lineBarsData: lines,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 9, color: _textLight),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: math.max(1, _chartMaxX / 5),
                      getTitlesWidget: (v, m) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 9, color: _textLight),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _axisLines(int part, bool acc) {
    final colors = [Colors.orange, Colors.blue, Colors.green];
    return List.generate(3, (axis) {
      return LineChartBarData(
        spots: _spotsForAxis(part, axis, acc),
        color: colors[axis],
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      );
    });
  }

  Widget _buildChartSection(int part) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '訊號對照 — ${_partLabels[part]}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        _phaseTitleBar(),
        _signalChart(
          title: '加速度計 (m/s²)',
          minY: -25,
          maxY: 25,
          lines: _axisLines(part, true),
        ),
        const SizedBox(height: 12),
        _signalChart(
          title: '陀螺儀 (deg/s)',
          minY: -220,
          maxY: 220,
          lines: _axisLines(part, false),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniLegend(Colors.orange, 'X'),
            SizedBox(width: 12),
            _MiniLegend(Colors.blue, 'Y'),
            SizedBox(width: 12),
            _MiniLegend(Colors.green, 'Z'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCream,
      appBar: AppBar(
        backgroundColor: _bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _textDark, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'IMU 訊號圖',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryOrange),
            )
          : !_hasData
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '找不到 IMU 時序資料。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textLight, height: 1.45),
                ),
              ),
            )
          : Column(
              children: [
                Material(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: _primaryOrange,
                    unselectedLabelColor: _textLight,
                    indicatorColor: _primaryOrange,
                    tabs: [for (final p in _partLabels) Tab(text: p)],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (int part = 0; part < _partLabels.length; part++)
                        _buildChartSection(part),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniLegend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _textDark)),
      ],
    );
  }
}
