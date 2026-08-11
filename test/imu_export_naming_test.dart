import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tug_gait_analysis/imu_export_naming.dart';

void main() {
  test('formatDateTime uses local date and HH-mm-ss', () {
    final s = ImuExportNaming.formatDateTime(
      DateTime(2026, 5, 19, 14, 30, 45),
    );
    expect(s, '2026-05-19_14-30-45');
  });

  test('resolveBasename adds _2 when stem exists', () async {
    final dir = await Directory.systemTemp.createTemp('tug_naming_test');
    try {
      await File('${dir.path}/tug_2026-05-19_14-30-45.json').create();
      final when = DateTime(2026, 5, 19, 14, 30, 45);

      final first = await ImuExportNaming.resolveBasename(
        directory: dir,
        recordedAt: when,
      );
      expect(first, 'tug_2026-05-19_14-30-45_2');

      await File('${dir.path}/$first.json').create();
      final third = await ImuExportNaming.resolveBasename(
        directory: dir,
        recordedAt: when,
      );
      expect(third, 'tug_2026-05-19_14-30-45_3');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('CSV basename matches JSON stem when csv absent', () async {
    final dir = await Directory.systemTemp.createTemp('tug_naming_csv');
    try {
      final jsonPath = '${dir.path}/tug_2026-05-19_15-00-00.json';
      await File(jsonPath).create();
      final when = DateTime(2026, 5, 19, 15, 0, 0);

      final stem = await ImuExportNaming.resolveBasenameForCsv(
        directory: dir,
        jsonPath: jsonPath,
        recordedAt: when,
      );
      expect(stem, 'tug_2026-05-19_15-00-00');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
