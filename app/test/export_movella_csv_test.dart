import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tug_gait_analysis/imu_series_storage.dart';
import 'package:tug_gait_analysis/movella_dot_csv_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JSON rows export to Movella 71-column CSV', () async {
    const jsonPath = 'test_data/imu_series_4.json';
    expect(File(jsonPath).existsSync(), true);

    final payload = await ImuSeriesStorage.loadFile(jsonPath);
    final jsonRows = await ImuSeriesStorage.loadRowsFromFile(jsonPath);
    final recordedAt = DateTime.parse(payload!['recordedAt'] as String);
    final outPath = '${Directory.systemTemp.path}/export_test_movella.csv';
    await MovellaDotCsvExport.writeToFile(
      jsonRows!,
      outPath,
      recordedAt: recordedAt,
    );
    final raw = await File(outPath).readAsString();
    final lines = raw.split('\n').where((l) => l.isNotEmpty).toList();

    expect(lines.length, greaterThan(10));
    expect(lines[0].startsWith('Format=7'), true);
    expect(lines[1].startsWith('Time,Accelerometer'), true);
    expect(lines[2].startsWith(',X,Y,Z'), true);

    final dataRows = const CsvToListConverter(eol: '\n').convert(
      lines.sublist(3).join('\n'),
    );
    expect(dataRows.length, greaterThan(10));
    expect(dataRows.first.length, MovellaDotCsvExport.movellaColumnCount);

    expect(dataRows.length, jsonRows.length);
    expect(payload['sampleRateHz'], 60.0);

    // Acc 左小腿 X 應與 JSON 第 1 欄一致
    final exportedAx = double.parse(dataRows[0][1].toString());
    expect(exportedAx, closeTo((jsonRows[0][1] as num).toDouble(), 0.0001));
  });
}
