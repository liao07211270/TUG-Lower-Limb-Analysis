import 'dart:io';

import 'package:path/path.dart' as p;

/// 即時測試 IMU 匯出檔名：`tug_{日期}_{時間}`，衝突時加 `_2`、`_3`…
class ImuExportNaming {
  ImuExportNaming._();

  static const String prefix = 'tug';

  /// 例：`2026-05-19_14-30-45`
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${local.year}-${two(local.month)}-${two(local.day)}';
    final time =
        '${two(local.hour)}-${two(local.minute)}-${two(local.second)}';
    return '${date}_$time';
  }

  /// 不含副檔名的主檔名，例：`tug_2026-05-19_14-30-45` 或 `tug_2026-05-19_14-30-45_2`。
  static Future<String> resolveBasename({
    required Directory directory,
    required DateTime recordedAt,
  }) async {
    final stem = '${prefix}_${formatDateTime(recordedAt)}';
    if (!await _basenameExists(directory, stem)) {
      return stem;
    }
    for (int seq = 2; seq < 1000; seq++) {
      final candidate = '${stem}_$seq';
      if (!await _basenameExists(directory, candidate)) {
        return candidate;
      }
    }
    throw StateError('無法產生唯一檔名（已嘗試 _2～_999）');
  }

  /// 由既有 JSON 路徑推導 CSV 主檔名（與 JSON 同 stem）；無法解析時用 [recordedAt] 新建。
  static Future<String> resolveBasenameForCsv({
    required Directory directory,
    required String? jsonPath,
    required DateTime recordedAt,
  }) async {
    if (jsonPath != null && jsonPath.isNotEmpty) {
      final stem = p.basenameWithoutExtension(jsonPath);
      if (stem.startsWith('${prefix}_')) {
        if (!await _basenameExists(directory, stem, extension: '.csv')) {
          return stem;
        }
        for (int seq = 2; seq < 1000; seq++) {
          final base = stem.contains(RegExp(r'_\d+$'))
              ? stem.replaceFirst(RegExp(r'_\d+$'), '_$seq')
              : '${stem}_$seq';
          if (!await _basenameExists(directory, base, extension: '.csv')) {
            return base;
          }
        }
      }
    }
    return resolveBasename(directory: directory, recordedAt: recordedAt);
  }

  static Future<String> jsonFileName({
    required Directory directory,
    required DateTime recordedAt,
  }) async {
    final base = await resolveBasename(
      directory: directory,
      recordedAt: recordedAt,
    );
    return '$base.json';
  }

  static Future<String> csvFileName({
    required Directory directory,
    required DateTime recordedAt,
    String? fromJsonPath,
  }) async {
    final base = await resolveBasenameForCsv(
      directory: directory,
      jsonPath: fromJsonPath,
      recordedAt: recordedAt,
    );
    return '$base.csv';
  }

  static Future<bool> _basenameExists(
    Directory directory,
    String basename, {
    String? extension,
  }) async {
    if (extension != null) {
      return File(p.join(directory.path, '$basename$extension')).exists();
    }
    for (final ext in ['.json', '.csv']) {
      if (await File(p.join(directory.path, '$basename$ext')).exists()) {
        return true;
      }
    }
    return false;
  }
}
