/// IMU 列欄位配置：與 [Lowerlimbs.m]、原始 CSV（如 20251118-FS*.csv）一致。
///
/// CSV / MATLAB 五段順序（非 UI 綁定槽位順序）：
///   左小腿 → 右小腿 → 左大腿 → 右大腿 → 腰部
///
/// 每段 6 欄：Acc X,Y,Z + Gyro X,Y,Z（Dart 0-based index）。
class ImuColumnLayout {
  ImuColumnLayout._();

  static const int rowWidth = 63;

  /// 與 `data_processor.dart` / MATLAB `(4:r, 2:7)` 等切片一致的起始 index。
  static const Map<String, int> partToRowStart = {
    '左小腿': 1,
    '右小腿': 15,
    '左大腿': 29,
    '右大腿': 43,
    '腰部': 57,
  };

  /// 訓練管線使用的五顆順序（MATLAB AccGyro 第 1～5 組）。
  static const List<String> trainingPartOrder = [
    '左小腿',
    '右小腿',
    '左大腿',
    '右大腿',
    '腰部',
  ];

  static int? rowStartForPart(String? part) {
    if (part == null) return null;
    return partToRowStart[part];
  }

  /// 將一顆感測器的 Acc/Gyro 寫入 63 欄列的對應區塊。
  static void writeSensorToRow(
    List<dynamic> row,
    String part,
    double ax,
    double ay,
    double az,
    double gx,
    double gy,
    double gz,
  ) {
    final start = rowStartForPart(part);
    if (start == null) return;
    row[start] = ax;
    row[start + 1] = ay;
    row[start + 2] = az;
    row[start + 3] = gx;
    row[start + 4] = gy;
    row[start + 5] = gz;
  }
}
