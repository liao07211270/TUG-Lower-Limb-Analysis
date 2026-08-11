import 'package:flutter/material.dart';
import '../ble_session.dart';
import '../imu_series_storage.dart';
import '../movella_dot_csv_export.dart';
import 'imu_signal_chart_screen.dart';
import '../tug_phase_display.dart';

// === 全域主題配色 (維持專案一致的奶油抹茶風) ===
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color textDark = Color(0xFF4A4A4A);
const Color textLight = Color(0xFF9E9E9E);

/// 單一階段列（時間軸／圖例）。
class TugPhase {
  final String name;
  final double duration;
  final Color color;
  TugPhase({required this.name, required this.duration, required this.color});
}

class TugResultScreen extends StatefulWidget {
  final double totalTime;
  final double standUpTime;
  final double walkGoTime;
  final double turn1Time;
  final double walkReturnTime;
  final double turn2Time;
  final double sitDownTime;
  final int? historyId;
  final String? imuJsonPath;
  final int? imuRowCount;

  const TugResultScreen({
    super.key,
    required this.totalTime,
    required this.standUpTime,
    required this.walkGoTime,
    required this.turn1Time,
    required this.walkReturnTime,
    required this.turn2Time,
    required this.sitDownTime,
    this.historyId,
    this.imuJsonPath,
    this.imuRowCount,
  });

  @override
  State<TugResultScreen> createState() => _TugResultScreenState();
}

class _TugResultScreenState extends State<TugResultScreen> {
  bool _exportingJson = false;
  bool _exportingCsv = false;

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  Future<void> _exportImuJson() async {
    final path = widget.imuJsonPath;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到 IMU 錄製檔，請重新完成一次測試。')),
      );
      return;
    }
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

  void _openSignalCharts() {
    if (widget.imuJsonPath == null || widget.imuJsonPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到 IMU 錄製檔，無法顯示訊號圖。')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImuSignalChartScreen(
          imuSeriesPath: widget.imuJsonPath,
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

  Future<void> _exportImuCsv() async {
    final path = widget.imuJsonPath;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到 IMU 錄製檔，請重新完成一次測試。')),
      );
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final phaseDurations = TugSixPhaseDurations(
      standUp: widget.standUpTime,
      walkGo: widget.walkGoTime,
      turn1: widget.turn1Time,
      walkReturn: widget.walkReturnTime,
      turn2: widget.turn2Time,
      sitDown: widget.sitDownTime,
    );
    final List<TugPhase> phases = phaseDurations
        .toTimelineSegments()
        .map(
          (s) => TugPhase(
            name: s.name,
            duration: s.duration,
            color: s.color,
          ),
        )
        .toList();

    final hasImuExport =
        widget.imuJsonPath != null && widget.imuJsonPath!.isNotEmpty;

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        automaticallyImplyLeading: false, // 隱藏返回鍵
        title: const Text(
          '測試分析報告',
          style: TextStyle(color: textDark, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _buildMainResultCard(),
            const SizedBox(height: 32),
            _buildTimelineChart(phases),
            const SizedBox(height: 32),
            if (hasImuExport && widget.imuRowCount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '已儲存 ${widget.imuRowCount} 列 IMU（60 Hz）',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            if (hasImuExport)
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: primaryOrange, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            if (hasImuExport) const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: hasImuExport && !_exportingJson && !_exportingCsv
                  ? _exportImuJson
                  : null,
              icon: _exportingJson
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryOrange,
                      ),
                    )
                  : const Icon(
                      Icons.file_download_outlined,
                      color: primaryOrange,
                    ),
              label: Text(
                _exportingJson ? '準備分享檔案…' : '匯出 IMU 原始數據 (JSON)',
                style: const TextStyle(
                  color: primaryOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: primaryOrange, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: hasImuExport && !_exportingJson && !_exportingCsv
                  ? _exportImuCsv
                  : null,
              icon: _exportingCsv
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryOrange,
                      ),
                    )
                  : const Icon(
                      Icons.table_chart_outlined,
                      color: primaryOrange,
                    ),
              label: Text(
                _exportingCsv ? '準備 CSV…' : '匯出 IMU 感測器數據 (60 Hz CSV)',
                style: const TextStyle(
                  color: primaryOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: primaryOrange, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final sensors = BleSessionManager.instance.activeSensors;
                if (sensors.isNotEmpty) {
                  await BleSessionManager.instance.preserveSession(sensors);
                }
                if (!context.mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                '完成並返回首頁',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // == 元件 A：總耗時卡片 ==
  Widget _buildMainResultCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'TUG 總耗時',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.totalTime.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '秒',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // == 🏆 元件 B：核心：橫向長條圖 (Stacked Bar) 🏆 ==
  Widget _buildTimelineChart(List<TugPhase> phases) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time_filled, color: textLight, size: 18),
              SizedBox(width: 8),
              Text(
                '各階段動作時間拆解',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. 本體：橫向堆疊長條圖
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: Row(
                children:
                    phases.where((p) => p.duration > 0).map((phase) {
                      int flexValue = (phase.duration * 100).toInt();
                      return Flexible(
                        flex: flexValue == 0 ? 1 : flexValue,
                        child: Container(color: phase.color),
                      );
                    }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. 圖例與純秒數數據表
          _buildLegendTable(phases),
        ],
      ),
    );
  }

  Widget _buildLegendTable(List<TugPhase> phases) {
    return Column(
      children:
          phases.map((phase) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  // 色塊指標
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: phase.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 動作名稱
                  Expanded(
                    child: Text(
                      phase.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 秒數呈現 (準確到小數點後 2 位)
                  Text(
                    '${phase.duration.toStringAsFixed(2)} 秒',
                    style: const TextStyle(
                      fontSize: 14,
                      color: textLight,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ), // 數字等寬對齊
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  // == 元件 C：狀態卡 ==
  Widget _buildStatusTile(
    IconData icon,
    String title,
    String subtitle,
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color[50], shape: BoxShape.circle),
            child: Icon(icon, color: color[400]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: textLight),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: Colors.green[400], size: 20),
        ],
      ),
    );
  }
}
