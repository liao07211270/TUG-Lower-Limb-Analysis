import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tug_gait_analysis/tug_analysis_pipeline2.dart';

/// 用 60 Hz CSV 跑 Pipeline2（與即時測試相同管線）。
///
/// 預設讀取 test_data/imu_60hz.csv；可改 [kCsvPath] 或設環境變數 IMU_CSV_PATH。
/// 執行：flutter test test/replay_imu_csv_pipeline2_test.dart
const String kCsvPath = 'test_data/tug_2026-05-19_14-48-19.csv';

/// flutter test 的工作目錄不一定是專案根目錄，需依 pubspec.yaml 定位。
String _projectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

String _resolveCsvPath() {
  final root = _projectRoot();

  final fromEnv = Platform.environment['IMU_CSV_PATH'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return p.isAbsolute(fromEnv) ? fromEnv : p.normalize(p.join(root, fromEnv));
  }

  final target = p.normalize(p.join(root, kCsvPath));
  if (File(target).existsSync()) {
    return target;
  }

  throw StateError(
    '找不到 CSV：$target\n'
    '請確認檔案存在，或設定 IMU_CSV_PATH=絕對路徑',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Pipeline2 from 60 Hz CSV', () async {
    final csvPath = _resolveCsvPath();
    final file = File(csvPath);
    expect(
      file.existsSync(),
      true,
      reason:
          '找不到 CSV。請將 60 Hz 檔放在 test_data/（例如 imu_60hz.csv），'
          '或設定 IMU_CSV_PATH=路徑',
    );

    // Movella 匯出多為 Unix 換行 (\n)；預設 eol 為 \r\n 會把整檔解析成 1 列。
    final fields = await file
        .openRead()
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(eol: '\n'))
        .toList();
    expect(fields.length, greaterThan(10));

    print('--- 輸入 ---');
    print('專案根目錄: ${_projectRoot()}');
    print('檔案: $csvPath');
    print('列數: ${fields.length}（約 ${(fields.length / 60).toStringAsFixed(1)} 秒 @ 60 Hz）');

    final result = await TugAnalysisPipeline2().runAnalysis(fields);

    print('--- Pipeline2 結果 ---');
    print('總: ${result.totalTime.toStringAsFixed(2)} s');
    print('起: ${result.standUpTime.toStringAsFixed(2)}');
    print('去: ${result.walkGoTime.toStringAsFixed(2)}');
    print('轉向: ${result.turn1Time.toStringAsFixed(2)}');
    print('回程: ${result.walkReturnTime.toStringAsFixed(2)}');
    print('轉身(準備坐下): ${result.turn2Time.toStringAsFixed(2)}');
    print('坐下: ${result.sitDownTime.toStringAsFixed(2)}');
    print('（RF 分佈見上方 🚀 [Pipeline] log）');
  });
}
