import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tug_gait_analysis/imu_series_storage.dart';
import 'package:tug_gait_analysis/tug_analysis_pipeline2.dart';

/// 離線重跑 Pipeline2（60 Hz + model2）。
///
/// 1. 把手機匯出的 JSON 放到 [test_data/]（例如 imu_series_4.json）
/// 2. 在專案根目錄執行：
///    flutter test test/replay_imu_json_test.dart
///
/// 若檔名不同，改下面 [kImuJsonPath]。
const kImuJsonPath = 'test_data/imu_series_4.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Replay Pipeline2 from test_data JSON', () async {
    final file = File(kImuJsonPath);
    expect(
      file.existsSync(),
      true,
      reason: '找不到 $kImuJsonPath，請將手機匯出的 JSON 複製到 test_data/',
    );

    final payload = await ImuSeriesStorage.loadFile(kImuJsonPath);
    expect(payload, isNotNull);

    final rows = await ImuSeriesStorage.loadRowsFromFile(kImuJsonPath);
    expect(rows, isNotNull);
    expect(rows!.isNotEmpty, true);

    final sampleRate = (payload!['sampleRateHz'] as num?)?.toDouble() ?? 60;
    final rowCount = rows.length;
    print('--- 輸入 ---');
    print('檔案: $kImuJsonPath');
    print('列數: $rowCount');
    print('標示取樣率: ${sampleRate} Hz');
    print('約 ${(rowCount / sampleRate).toStringAsFixed(1)} 秒（列數÷60）');

    final saved = payload['analysisResult'];
    if (saved is Map) {
      print('--- 手機當時結果（JSON 內 analysisResult）---');
      print(saved);
    }

    final result = await TugAnalysisPipeline2().runAnalysis(rows);

    print('--- 電腦離線 Pipeline2 結果 ---');
    print('總: ${result.totalTime.toStringAsFixed(2)} s');
    print('起: ${result.standUpTime.toStringAsFixed(2)}');
    print('去: ${result.walkGoTime.toStringAsFixed(2)}');
    print('轉1: ${result.turn1Time.toStringAsFixed(2)}');
    print('回: ${result.walkReturnTime.toStringAsFixed(2)}');
    print('轉2: ${result.turn2Time.toStringAsFixed(2)}');
    print('坐: ${result.sitDownTime.toStringAsFixed(2)}');
    print('（RF 分佈與最終標籤請看上方 🚀 [Pipeline] log）');
  });
}
