import 'dart:io';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'imu_column_layout.dart';
import 'imu_export_naming.dart';
import 'imu_series_storage.dart';

/// 將 App 內 63 欄 IMU 列匯出為 Movella DOT 匯出風格 CSV（71 欄、3 行表頭），
/// 與 [test_data/imu_60hz.csv] 相同，供 `replay_imu_csv_pipeline2_test` 與 Movella 工具使用。
///
/// Acc/Gyro 在 63 欄與 71 欄的 index 一致（1–6、15–20…）；無 Mag/Orient。
class MovellaDotCsvExport {
  MovellaDotCsvExport._();

  static const int movellaColumnCount = 71;

  /// 與 `test_data/imu_60hz.csv` 前三行一致（含 Left Skank 拼字）。
  static const List<String> headerRows = [
    'Format=7,10908,,,Left Skank,,,,,,,,,,,14140,,,Right Shank,,,,,,,,,,,15955,,,Left Thigh,,,,,,,,,,,15985,,,Right Thigh,,,,,,,,,,,16169,,,Waist,,,,,,,,,,',
    'Time,Accelerometer,,,Gyroscope,,,Magnetometer,,,Barometer,Orientation,,,,Accelerometer,,,Gyroscope,,,Magnetometer,,,Barometer,Orientation,,,,Accelerometer,,,Gyroscope,,,Magnetometer,,,Barometer,Orientation,,,,Accelerometer,,,Gyroscope,,,Magnetometer,,,Barometer,Orientation,,,,Accelerometer,,,Gyroscope,,,Magnetometer,,,Barometer,Orientation,,,',
    ',X,Y,Z,X,Y,Z,X,Y,Z,,S,X,Y,Z,X,Y,Z,X,Y,Z,X,Y,Z,,S,X,Y,Z,X,Y,Z,X,Y,Z,X,Y,Z,,S,X,Y,Z,X,Y,Z,X,Y,Z,X,Y,Z,,S,X,Y,Z,X,Y,Z,X,Y,Z,X,Y,Z,,S,X,Y,Z',
  ];

  /// 71 欄中寫入 Acc/Gyro 的 index（與 [ImuColumnLayout] / Pipeline 一致）。
  static final List<int> accGyroColumnIndices = [
    for (final part in ImuColumnLayout.trainingPartOrder)
      for (int o = 0; o < 6; o++)
        ImuColumnLayout.partToRowStart[part]! + o,
  ];

  static const double sampleRateHz = 60.0;

  /// 由 JSON 錄製檔產生 CSV，回傳寫入路徑。
  static Future<String> writeFromJsonFile(
    String jsonPath, {
    String? outputFileName,
  }) async {
    final payload = await ImuSeriesStorage.loadFile(jsonPath);
    final rows = await ImuSeriesStorage.loadRowsFromFile(jsonPath);
    if (payload == null || rows == null || rows.isEmpty) {
      throw StateError('無法讀取 IMU JSON：$jsonPath');
    }

    final recordedAtStr = payload['recordedAt'] as String?;
    final recordedAt = recordedAtStr != null
        ? DateTime.tryParse(recordedAtStr) ?? DateTime.now()
        : DateTime.now();
    final rate =
        (payload['sampleRateHz'] as num?)?.toDouble() ?? sampleRateHz;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = outputFileName != null
        ? '$outputFileName.csv'
        : await ImuExportNaming.csvFileName(
            directory: dir,
            recordedAt: recordedAt,
            fromJsonPath: jsonPath,
          );
    final outPath = p.join(dir.path, fileName);

    await writeToFile(
      rows,
      outPath,
      recordedAt: recordedAt,
      sampleRateHz: rate,
    );
    return outPath;
  }

  /// 寫入 Movella 風格 CSV（UTF-8、Unix 換行 `\n`）。
  static Future<void> writeToFile(
    List<List<dynamic>> rows,
    String fullPath, {
    required DateTime recordedAt,
    double sampleRateHz = MovellaDotCsvExport.sampleRateHz,
  }) async {
    final filtered = rows.where((r) => r.length >= ImuColumnLayout.rowWidth).toList();
    if (filtered.isEmpty) {
      throw StateError('沒有可匯出的 IMU 列（需至少 ${ImuColumnLayout.rowWidth} 欄）');
    }

    final baseMicros = recordedAt.microsecondsSinceEpoch;
    final stepMicros = (1000000 / sampleRateHz).round();

    final dataRows = <List<String>>[];
    for (int i = 0; i < filtered.length; i++) {
      dataRows.add(_movellaDataRow(filtered[i], baseMicros + i * stepMicros));
    }

    final buffer = StringBuffer();
    for (final h in headerRows) {
      buffer.writeln(h);
    }
    final csvBody = const ListToCsvConverter(eol: '\n').convert(dataRows);
    buffer.write(csvBody);

    final file = File(fullPath);
    await file.writeAsString(buffer.toString());
  }

  static List<String> _movellaDataRow(List<dynamic> row63, int timestampMicros) {
    final out = List<String>.filled(movellaColumnCount, '');
    out[0] = timestampMicros.toString();

    for (final col in accGyroColumnIndices) {
      if (col >= row63.length) continue;
      final v = _toDouble(row63[col]);
      out[col] = _formatSensorValue(v);
    }
    return out;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static String _formatSensorValue(double v) {
    if (v == 0.0) return '0.000000';
    return v.toStringAsFixed(6);
  }

  static Future<void> shareFile(
    String fullPath, {
    String? shareText,
    Rect? sharePositionOrigin,
  }) async {
    final file = File(fullPath);
    if (!await file.exists()) {
      throw StateError('找不到匯出檔：$fullPath');
    }
    await Share.shareXFiles(
      [
        XFile(
          fullPath,
          mimeType: 'text/csv',
          name: p.basename(fullPath),
        ),
      ],
      text: shareText ?? 'TUG 即時錄製 IMU（60 Hz Movella CSV）',
      subject: 'TUG IMU CSV export',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
