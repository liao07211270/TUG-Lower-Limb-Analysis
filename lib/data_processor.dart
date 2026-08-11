import 'dart:math';

class TugDataProcessor {
  // 這是給 Web 模式使用的核心方法：直接處理從 CSV 解析出來的 fields 列表
  Future<List<List<double>>> processFromFields(
    List<List<dynamic>> fields,
  ) async {
    try {
      // CSV 上傳檔有 3 行表頭；App 即時錄製資料沒有表頭。
      // 逐列保留真正的 IMU 數據，可同時支援兩種來源。
      final dataRows = fields.where(_rowLooksLikeImuData).toList();
      if (dataRows.isEmpty) return [];

      List<List<double>> raw30List = [];
      for (var row in dataRows) {
        // 確保每一行至少有 63 個欄位 (最後一個 Sensor 結束在 index 62)
        if (row.length < 63) continue;

        // 2. 精確抓取 30 個原始通道 (對應 2:7, 16:21, 30:35, 44:49, 58:63)
        List<double> raw30 = [
          ..._parseSlice(row, 1, 6), // Sensor 1 (標頭後的第2到7欄)
          ..._parseSlice(row, 15, 20), // Sensor 2
          ..._parseSlice(row, 29, 34), // Sensor 3
          ..._parseSlice(row, 43, 48), // Sensor 4
          ..._parseSlice(row, 57, 62), // Sensor 5
        ];
        raw30List.add(raw30);
      }

      // 3. 計算 70 通道 (包含兩兩合成軸與三軸合成軸)
      List<List<double>> seventyChannelData = [];
      for (var r30 in raw30List) {
        List<double> channels = List.from(r30); // 1-30 通道

        // 兩兩合成軸 (31-60 通道)
        for (int j = 0; j < 30; j += 3) {
          channels.add(sqrt(r30[j] * r30[j] + r30[j + 1] * r30[j + 1])); // XY
          channels.add(sqrt(r30[j] * r30[j] + r30[j + 2] * r30[j + 2])); // XZ
          channels.add(
            sqrt(r30[j + 1] * r30[j + 1] + r30[j + 2] * r30[j + 2]),
          ); // YZ
        }

        // 三軸合成軸 (61-70 通道)
        for (int j = 0; j < 30; j += 3) {
          channels.add(
            sqrt(
              r30[j] * r30[j] +
                  r30[j + 1] * r30[j + 1] +
                  r30[j + 2] * r30[j + 2],
            ),
          );
        }
        seventyChannelData.add(channels);
      }
      return seventyChannelData;
    } catch (e) {
      print("❌ DataProcessor Web 處理錯誤: $e");
      rethrow;
    }
  }

  bool _rowLooksLikeImuData(List<dynamic> row) {
    if (row.length < 63) return false;
    for (final range in const [
      [1, 6],
      [15, 20],
      [29, 34],
      [43, 48],
      [57, 62],
    ]) {
      for (int i = range[0]; i <= range[1]; i++) {
        if (double.tryParse(row[i]?.toString() ?? '') == null) {
          return false;
        }
      }
    }
    return true;
  }

  List<double> _parseSlice(List<dynamic> row, int start, int end) {
    List<double> res = [];
    for (int i = start; i <= end; i++) {
      String s = row[i]?.toString() ?? "0";
      res.add(double.tryParse(s) ?? 0.0);
    }
    return res;
  }
}
