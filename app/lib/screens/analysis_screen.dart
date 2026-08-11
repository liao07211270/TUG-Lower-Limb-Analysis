import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../imu_series_storage.dart';
import '../movella_dot_csv_export.dart';
import '../tug_phase_display.dart';
import 'imu_signal_chart_screen.dart';

// === 奶油風主題（與連線／錄製頁 textDark 對齊）===
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color accentBlue = Color(0xFFABD7FB);
const Color textDark = Color(0xFF4A4A4A);
const Color textLight = Color(0xFF9E9E9E);

/// 與 [kTugSixPhaseColors] 相同，保留別名供圖表區塊使用。
const List<Color> kPhaseStackColors = kTugSixPhaseColors;

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  List<Map<String, dynamic>> _historyList = [];
  double _avgTime = 0.0;
  double _bestTime = 0.0;
  int _testCount = 0;
  int _highRiskCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    final data = await DatabaseHelper.instance.getAllHistory();
    if (!mounted) return;

    double sum = 0;
    double best = double.infinity;
    int high = 0;
    for (final r in data) {
      final t = (r['total_time'] as num?)?.toDouble() ?? 0;
      sum += t;
      if (t < best) best = t;
      if (t > 15) high++;
    }

    setState(() {
      _historyList = data;
      _testCount = data.length;
      _avgTime = data.isEmpty ? 0 : sum / data.length;
      _bestTime = data.isEmpty ? 0 : best;
      _highRiskCount = high;
      _isLoading = false;
    });
  }

  void _openDetail(Map<String, dynamic> record) {
    final id = record['id'] as int?;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => AnalysisDetailScreen(
              totalTime: (record['total_time'] as num?)?.toDouble() ?? 0,
              standUpTime: (record['stand_up'] as num?)?.toDouble() ?? 0,
              walkGoTime: (record['walk_go'] as num?)?.toDouble() ?? 0,
              turn1Time: (record['turn1'] as num?)?.toDouble() ?? 0,
              walkReturnTime: (record['walk_return'] as num?)?.toDouble() ?? 0,
              turn2Time: (record['turn2'] as num?)?.toDouble() ?? 0,
              sitDownTime: (record['sit_down'] as num?)?.toDouble() ?? 0,
              historyId: id,
              imuSeriesPath: record['imu_series_path'] as String?,
            ),
      ),
    );
  }

  List<BarChartRodStackItem> _rodStackForRecord(Map<String, dynamic> r) {
    double su = (r['stand_up'] as num?)?.toDouble() ?? 0;
    double wg = (r['walk_go'] as num?)?.toDouble() ?? 0;
    double t1 = (r['turn1'] as num?)?.toDouble() ?? 0;
    double wr = (r['walk_return'] as num?)?.toDouble() ?? 0;
    double t2 = (r['turn2'] as num?)?.toDouble() ?? 0;
    double sd = (r['sit_down'] as num?)?.toDouble() ?? 0;

    double y = 0;
    final items = <BarChartRodStackItem>[];
    final vals = [su, wg, t1, wr, t2, sd];
    for (int i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v <= 0) continue;
      items.add(BarChartRodStackItem(y, y + v, kPhaseStackColors[i]));
      y += v;
    }
    if (items.isEmpty) {
      items.add(BarChartRodStackItem(0, 0.01, Colors.grey.withOpacity(0.2)));
    }
    return items;
  }

  double _stackTotal(Map<String, dynamic> r) {
    double su = (r['stand_up'] as num?)?.toDouble() ?? 0;
    double wg = (r['walk_go'] as num?)?.toDouble() ?? 0;
    double t1 = (r['turn1'] as num?)?.toDouble() ?? 0;
    double wr = (r['walk_return'] as num?)?.toDouble() ?? 0;
    double t2 = (r['turn2'] as num?)?.toDouble() ?? 0;
    double sd = (r['sit_down'] as num?)?.toDouble() ?? 0;
    final s = su + wg + t1 + wr + t2 + sd;
    return s > 0 ? s : ((r['total_time'] as num?)?.toDouble() ?? 0.01);
  }

  Widget _buildStackedTrendChart() {
    if (_historyList.length < 2) {
      return const SizedBox.shrink();
    }
    final ordered = _historyList.reversed.toList();
    double maxY = 1;
    for (final r in ordered) {
      final t = _stackTotal(r);
      if (t > maxY) maxY = t;
    }
    maxY *= 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '分段時間趨勢（堆疊直方圖）',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Y 軸為各階段秒數堆疊；由左至右為較舊→較新紀錄',
          style: TextStyle(fontSize: 12, color: textLight),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: math.max(1, maxY / 5),
                getDrawingHorizontalLine:
                    (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= ordered.length) {
                        return const SizedBox.shrink();
                      }
                      final d = ordered[i]['date']?.toString() ?? '';
                      final short =
                          d.length > 6 ? d.substring(d.length - 5) : d;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          short,
                          style: const TextStyle(fontSize: 9, color: textLight),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10, color: textLight),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < ordered.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        fromY: 0,
                        toY: _stackTotal(ordered[i]),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        rodStackItems: _rodStackForRecord(ordered[i]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (int i = 0; i < kTugSixPhaseNames.length; i++)
              _LegendChip(kTugSixPhaseNames[i], kPhaseStackColors[i]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: primaryOrange),
                )
                : RefreshIndicator(
                  color: primaryOrange,
                  onRefresh: _loadRealData,
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      const Text(
                        '步態分析',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '追蹤您的 TUG 測試歷史與趨勢',
                        style: TextStyle(fontSize: 16, color: textLight),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryOrange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.timeline_rounded,
                                    color: primaryOrange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '平均測試時間',
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _testCount == 0
                                          ? '-- 秒'
                                          : '${_avgTime.toStringAsFixed(1)} 秒',
                                      style: const TextStyle(
                                        color: textDark,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: bgCream, thickness: 1.5),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn(
                                  '總測試次數',
                                  '$_testCount',
                                  accentBlue,
                                ),
                                _buildStatColumn(
                                  '最佳紀錄',
                                  _testCount == 0
                                      ? '-- s'
                                      : '${_bestTime.toStringAsFixed(1)}s',
                                  accentGreen,
                                ),
                                _buildStatColumn(
                                  '高風險次數',
                                  '$_highRiskCount',
                                  Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_historyList.length >= 2) ...[
                        _buildStackedTrendChart(),
                        const SizedBox(height: 32),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '歷史紀錄',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_historyList.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '尚未有測試紀錄\n完成裝置錄製或上傳 CSV 後可於此檢視',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._historyList.map((record) {
                          return _buildHistoryCard(
                            record: record,
                            onTap: () => _openDetail(record),
                          );
                        }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: textLight)),
      ],
    );
  }

  Widget _buildHistoryCard({
    required Map<String, dynamic> record,
    required VoidCallback onTap,
  }) {
    final total = (record['total_time'] as num?)?.toDouble() ?? 0;
    final color = total > 15 ? primaryOrange : accentGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bgCream, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.directions_walk_rounded, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['date']?.toString() ?? '未知日期',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '步態表現: ${record['phase'] ?? '—'}',
                    style: const TextStyle(fontSize: 13, color: textLight),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${total.toStringAsFixed(1)} s',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: textLight, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: textDark)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 單筆分析詳情（含 IMU 時序、階段背景、部位切換）
// ---------------------------------------------------------------------------

class AnalysisDetailScreen extends StatefulWidget {
  final double totalTime;
  final double standUpTime;
  final double walkGoTime;
  final double turn1Time;
  final double walkReturnTime;
  final double turn2Time;
  final double sitDownTime;
  final int? historyId;
  final String? imuSeriesPath;

  const AnalysisDetailScreen({
    super.key,
    required this.totalTime,
    this.standUpTime = 0.0,
    this.walkGoTime = 0.0,
    this.turn1Time = 0.0,
    this.walkReturnTime = 0.0,
    this.turn2Time = 0.0,
    this.sitDownTime = 0.0,
    this.historyId,
    this.imuSeriesPath,
  });

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  bool _imuLoading = true;
  bool _hasImuSeries = false;
  String? _loadedImuPath;
  bool _exportingJson = false;
  bool _exportingCsv = false;

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _loadImuSeries();
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
          _imuLoading = false;
          _hasImuSeries = false;
        });
      }
      return;
    }

    final payload = await ImuSeriesStorage.loadFile(path);
    if (!mounted) return;

    setState(() {
      _imuLoading = false;
      _hasImuSeries = payload != null;
      _loadedImuPath = path;
    });
  }

  void _openSignalCharts() {
    final path = _loadedImuPath ?? widget.imuSeriesPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此筆紀錄無 IMU 時序，無法顯示訊號圖。')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImuSignalChartScreen(
          imuSeriesPath: path,
          historyId: widget.historyId,
          standUpTime: widget.standUpTime,
          walkGoTime: widget.walkGoTime,
          turn1Time: widget.turn1Time,
          walkReturnTime: widget.walkReturnTime,
          turn2Time: widget.turn2Time,
          sitDownTime: widget.sitDownTime,
        ),
      ),
    );
  }

  Future<void> _exportImuJson() async {
    final path = _loadedImuPath;
    if (path == null || path.isEmpty) return;
    setState(() => _exportingJson = true);
    try {
      await ImuSeriesStorage.shareExportFile(
        path,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingJson = false);
    }
  }

  Future<void> _exportImuCsv() async {
    final path = _loadedImuPath;
    if (path == null || path.isEmpty) return;
    setState(() => _exportingCsv = true);
    try {
      final csvPath = await MovellaDotCsvExport.writeFromJsonFile(path);
      await MovellaDotCsvExport.shareFile(
        csvPath,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 匯出失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryOrange,
              ),
            )
          : Icon(icon, color: primaryOrange),
      label: Text(
        label,
        style: const TextStyle(
          color: primaryOrange,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: primaryOrange, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExport = _hasImuSeries && _loadedImuPath != null;
    final busy = _exportingJson || _exportingCsv;

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: textDark, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '分析結果',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _imuLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryOrange),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '分析完成！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 22,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '總花費時間',
                        style: TextStyle(
                          fontSize: 15,
                          color: textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.totalTime.toStringAsFixed(2)} 秒',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: primaryOrange,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Divider(color: bgCream, thickness: 2),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '各階段詳細數據',
                          style: TextStyle(
                            fontSize: 16,
                            color: textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(kTugSixPhaseNames.length, (i) {
                        final secs = TugSixPhaseDurations(
                          standUp: widget.standUpTime,
                          walkGo: widget.walkGoTime,
                          turn1: widget.turn1Time,
                          walkReturn: widget.walkReturnTime,
                          turn2: widget.turn2Time,
                          sitDown: widget.sitDownTime,
                        ).seconds;
                        return _phaseRow(kTugSixPhaseNames[i], secs[i]);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (canExport) ...[
                  _exportButton(
                    label: _exportingJson ? '準備 JSON…' : '匯出 IMU 原始數據 (JSON)',
                    icon: Icons.file_download_outlined,
                    loading: _exportingJson,
                    onPressed: busy ? null : _exportImuJson,
                  ),
                  const SizedBox(height: 10),
                  _exportButton(
                    label: _exportingCsv ? '準備 CSV…' : '匯出 IMU 感測器數據 (60 Hz CSV)',
                    icon: Icons.table_chart_outlined,
                    loading: _exportingCsv,
                    onPressed: busy ? null : _exportImuCsv,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openSignalCharts,
                    icon: const Icon(
                      Icons.show_chart_rounded,
                      color: primaryOrange,
                    ),
                    label: const Text(
                      '查看訊號圖',
                      style: TextStyle(
                        color: primaryOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: primaryOrange, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '完成並返回',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _phaseRow(String title, double time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${time.toStringAsFixed(2)} s',
            style: const TextStyle(
              fontSize: 15,
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

