import 'package:flutter/material.dart';

/// TUG 六階段顯示名稱（與 CSV 上傳／歷史紀錄一致）。
const List<String> kTugSixPhaseNames = [
  '起立',
  '去程',
  '轉向',
  '回程',
  '轉身（準備坐下）',
  '坐下',
];

/// 六階段時間軸配色（與 [AnalysisDetailScreen] 堆疊圖一致）。
const List<Color> kTugSixPhaseColors = [
  Color(0xFFFFCCBC),
  Color(0xFFC5E1A5),
  Color(0xFFE1BEE7),
  Color(0xFFBBDEFB),
  Color(0xFFD1C4E9),
  Color(0xFFFFECB3),
];

/// 六階段秒數（Pipeline / 資料庫欄位對應）。
class TugSixPhaseDurations {
  final double standUp;
  final double walkGo;
  final double turn1;
  final double walkReturn;
  final double turn2;
  final double sitDown;

  const TugSixPhaseDurations({
    required this.standUp,
    required this.walkGo,
    required this.turn1,
    required this.walkReturn,
    required this.turn2,
    required this.sitDown,
  });

  List<double> get seconds => [
        standUp,
        walkGo,
        turn1,
        walkReturn,
        turn2,
        sitDown,
      ];

  /// 供時間軸、圖例使用：(名稱, 秒數, 顏色)。
  List<({String name, double duration, Color color})> toTimelineSegments() {
    final out = <({String name, double duration, Color color})>[];
    final secs = seconds;
    for (int i = 0; i < kTugSixPhaseNames.length; i++) {
      out.add((
        name: kTugSixPhaseNames[i],
        duration: secs[i],
        color: kTugSixPhaseColors[i],
      ));
    }
    return out;
  }

  static TugSixPhaseDurations fromRecord(Map<String, dynamic> record) {
    double pick(String camel, String snake) {
      final v = record[camel] ?? record[snake];
      return (v as num?)?.toDouble() ?? 0;
    }

    return TugSixPhaseDurations(
      standUp: pick('standUp', 'stand_up'),
      walkGo: pick('walkGo', 'walk_go'),
      turn1: pick('turn1', 'turn1'),
      walkReturn: pick('walkReturn', 'walk_return'),
      turn2: pick('turn2', 'turn2'),
      sitDown: pick('sitDown', 'sit_down'),
    );
  }
}
