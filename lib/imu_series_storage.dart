import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'imu_export_naming.dart';

/// 將錄製的 63 欄列存成 JSON，供匯出、離線重跑 Pipeline2、圖表還原。
class ImuSeriesStorage {
  static const int currentVersion = 1;
  static const double defaultSampleRateHz = 60.0;

  /// 與 [saveRows] 相同格式，可附加分析結果供對照。
  static Map<String, dynamic> buildPayload(
    List<List<dynamic>> rows, {
    double sampleRateHz = defaultSampleRateHz,
    Map<String, dynamic>? analysisResult,
    String? recordedAtIso,
  }) {
    final filtered = _filterRows(rows);
    return {
      'version': currentVersion,
      'sampleRateHz': sampleRateHz,
      'recordedAt': recordedAtIso ?? DateTime.now().toIso8601String(),
      'rowCount': filtered.length,
      if (analysisResult != null) 'analysisResult': analysisResult,
      'rows': filtered,
    };
  }

  /// 寫入 App 文件目錄，回傳完整路徑。
  ///
  /// 檔名規則見 [ImuExportNaming]（例：`tug_2026-05-19_14-30-45.json`）。
  static Future<String> saveRows(
    List<List<dynamic>> rows, {
    DateTime? recordedAt,
    double sampleRateHz = defaultSampleRateHz,
    Map<String, dynamic>? analysisResult,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final when = recordedAt ?? DateTime.now();
    final fileName = await ImuExportNaming.jsonFileName(
      directory: dir,
      recordedAt: when,
    );
    final file = File(p.join(dir.path, fileName));

    final payload = buildPayload(
      rows,
      sampleRateHz: sampleRateHz,
      analysisResult: analysisResult,
      recordedAtIso: when.toIso8601String(),
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  /// 系統分享面板（AirDrop、儲存到檔案、郵件等）。
  static Future<void> shareExportFile(
    String fullPath, {
    String? shareText,
    Rect? sharePositionOrigin,
  }) async {
    final file = File(fullPath);
    if (!await file.exists()) {
      throw StateError('找不到匯出檔：$fullPath');
    }
    await Share.shareXFiles(
      [XFile(fullPath, mimeType: 'application/json', name: p.basename(fullPath))],
      text: shareText ?? 'TUG 即時錄製 IMU（60 Hz JSON）',
      subject: 'TUG IMU export',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<Map<String, dynamic>?> loadFile(String fullPath) async {
    try {
      final f = File(fullPath);
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// 從 JSON 載入 rows，供離線重跑 [TugAnalysisPipeline2]。
  static Future<List<List<dynamic>>?> loadRowsFromFile(String fullPath) async {
    final payload = await loadFile(fullPath);
    if (payload == null) return null;
    final raw = payload['rows'];
    if (raw is! List) return null;
    return raw.map((r) => List<dynamic>.from(r as List)).toList();
  }

  static List<List<double>> _filterRows(List<List<dynamic>> rows) {
    return rows
        .where((r) => r.length >= 63)
        .map(
          (r) => r
              .map((e) {
                if (e is num) return e.toDouble();
                return double.tryParse(e.toString()) ?? 0.0;
              })
              .toList(),
        )
        .toList();
  }
}
