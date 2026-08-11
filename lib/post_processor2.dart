import 'dart:math';

// ============================================================================
// 區塊 1：主要後處理流程 (物理規則過濾與分類展開)
// ============================================================================
class PostProcessor2 {
  /// 執行物理規則後處理，對齊新 0~6 七類模型驗證流程。
  List<int> applyPhysicalRulesOnly(
    List<int> pointPredictions,
    List<List<double>> data70,
  ) {
    List<int> segment = List.from(pointPredictions);
    int segLen = segment.length;
    if (segLen == 0) return segment;

    // 1. 取得第 61 個通道 (MATLAB: 61, Dart index: 60)
    List<double> rawAcc = data70.map((row) => row[60]).toList();
    // 2. 計算移動標準差 (MATLAB: movstd(Raw_Acc, 24))
    List<double> physicalStd = _calculateMovstd(rawAcc, 24);

    // --- 移除細碎片段 (MATLAB: blob_len < 80) ---
    int currentStart = -1;
    for (int i = 0; i < segLen; i++) {
      if (segment[i] != 0 && currentStart == -1) {
        currentStart = i;
      } else if (segment[i] == 0 && currentStart != -1) {
        if (i - currentStart < 80) {
          for (int k = currentStart; k < i; k++) segment[k] = 0;
        }
        currentStart = -1;
      }
    }
    if (currentStart != -1 && (segLen - currentStart) < 80) {
      for (int k = currentStart; k < segLen; k++) segment[k] = 0;
    }

    // --- 尋找 Active_Start 與 Model_End ---
    int activeStart = 0;
    int modelEnd = segLen - 1;
    List<int> activeIndices = [];
    for (int i = 0; i < segLen; i++) {
      if (segment[i] != 0) activeIndices.add(i);
    }
    if (activeIndices.isNotEmpty) {
      activeStart = activeIndices.first;
      modelEnd = activeIndices.last;
    } else {
      modelEnd = segLen - 1;
      activeStart = 0;
    }

    // --- 檢查 Check_Zone ---
    int checkZoneStart = max(0, modelEnd - 200);
    int sitCount = 0;
    for (int i = checkZoneStart; i <= modelEnd; i++) {
      if (segment[i] == 1) sitCount++;
    }

    int activeEnd = modelEnd;
    int splitPoint = (segLen / 2).round();

    // 分支 1：正常坐下邏輯
    if (sitCount > 2) {
      activeEnd = modelEnd;
      for (int ext = 1; ext <= 60; ext++) {
        int checkIdx = activeEnd + 1;
        if (checkIdx >= segLen || physicalStd[checkIdx] >= 0.10) break;
        segment[checkIdx] = 1;
        activeEnd = checkIdx;
      }

      List<int> sitIndices = [];
      for (int i = 0; i <= activeEnd; i++) {
        if (segment[i] == 1) sitIndices.add(i);
      }

      int lastSitStart = segLen - 1;
      if (sitIndices.isNotEmpty) {
        int breakIdx = 0;
        for (int i = sitIndices.length - 1; i > 0; i--) {
          if (sitIndices[i] - sitIndices[i - 1] > 1) {
            breakIdx = i;
            break;
          }
        }
        lastSitStart = sitIndices[breakIdx];
      }

      int forceTurnEnd = lastSitStart - 1;
      int forceTurnStart = max(0, lastSitStart - 50);

      for (int shift = 0; shift <= (50 - 14); shift++) {
        int checkIdx = forceTurnStart + shift;
        if (checkIdx < segLen && physicalStd[checkIdx] < 0.15) {
          forceTurnStart = checkIdx;
          break;
        }
      }

      if (forceTurnEnd > activeEnd) forceTurnEnd = activeEnd;
      if (forceTurnEnd > forceTurnStart && forceTurnEnd < segLen) {
        for (int k = forceTurnStart; k <= forceTurnEnd; k++) segment[k] = 3;
      }
      if (lastSitStart < activeEnd && activeEnd < segLen) {
        for (int k = lastSitStart; k <= activeEnd; k++) segment[k] = 1;
      }
      if (activeEnd < segLen - 1) {
        for (int k = activeEnd + 1; k < segLen; k++) segment[k] = 0;
      }

      splitPoint = (segLen / 2).round();
      List<int> validTurns = [];
      for (int i = 0; i < segLen; i++) {
        if (segment[i] == 3 && i < forceTurnStart) validTurns.add(i);
      }

      if (validTurns.isNotEmpty) {
        int maxLen = 0;
        int bestEnd = validTurns.last;
        int currentL = 1;

        for (int i = 1; i < validTurns.length; i++) {
          if (validTurns[i] - validTurns[i - 1] == 1) {
            currentL++;
          } else {
            if (currentL > maxLen) {
              maxLen = currentL;
              bestEnd = validTurns[i - 1];
            }
            currentL = 1;
          }
        }
        if (currentL > maxLen) bestEnd = validTurns.last;
        splitPoint = bestEnd;
      }

      if (forceTurnStart > splitPoint) {
        for (int k = splitPoint + 1; k < forceTurnStart; k++) {
          if (segment[k] == 1) segment[k] = 2;
        }
      }
    } else {
      // 分支 2：異常救回邏輯
      int walkEnd = modelEnd;
      for (int i = 0; i < segLen; i++) {
        if (physicalStd[i] > 0.10) walkEnd = i;
      }

      activeEnd = min(segLen - 1, walkEnd + 60);
      if (activeEnd < segLen - 1) {
        for (int k = activeEnd + 1; k < segLen; k++) segment[k] = 0;
      }
      if (walkEnd < activeEnd) {
        for (int k = walkEnd + 1; k <= activeEnd; k++) segment[k] = 1;
      }

      int rescueTurnStart = max(activeStart, walkEnd - 30 + 1);
      if (walkEnd > rescueTurnStart && walkEnd < segLen) {
        for (int k = rescueTurnStart; k <= walkEnd; k++) segment[k] = 3;
      }

      int forceTurnStart = rescueTurnStart;
      splitPoint = (segLen / 2).round();

      List<int> validTurns = [];
      for (int i = 0; i < segLen; i++) {
        if (segment[i] == 3 && i < forceTurnStart) validTurns.add(i);
      }
      if (validTurns.isNotEmpty) {
        int maxLen = 0;
        int bestEnd = validTurns.last;
        int currentL = 1;
        for (int i = 1; i < validTurns.length; i++) {
          if (validTurns[i] - validTurns[i - 1] == 1) {
            currentL++;
          } else {
            if (currentL > maxLen) {
              maxLen = currentL;
              bestEnd = validTurns[i - 1];
            }
            currentL = 1;
          }
        }
        if (currentL > maxLen) bestEnd = validTurns.last;
        splitPoint = bestEnd;
      }

      if (forceTurnStart > splitPoint) {
        for (int k = splitPoint + 1; k < forceTurnStart; k++) {
          segment[k] = 2;
        }
      }
    }

    // --- 將後半段展開為 4, 5, 6 ---
    for (int k = splitPoint + 1; k <= activeEnd && k < segLen; k++) {
      int val = segment[k];
      if (val == 2) {
        segment[k] = 4;
      } else if (val == 1) {
        segment[k] = 6;
      } else if (val == 3) {
        segment[k] = 5;
      }
    }

    // --- 前半段強制歸類防呆 ---
    for (int k = activeStart; k <= splitPoint && k < segLen; k++) {
      if (segment[k] >= 4) {
        segment[k] = segment[k] - 3;
      }
    }

    // --- 最終細碎片段平滑 (MATLAB: < 20) ---
    int finalStart = -1;
    for (int i = 0; i < segLen; i++) {
      if (segment[i] != 0 && finalStart == -1) {
        finalStart = i;
      } else if (segment[i] == 0 && finalStart != -1) {
        if (i - finalStart < 20) {
          for (int k = finalStart; k < i; k++) segment[k] = 0;
        }
        finalStart = -1;
      }
    }
    return segment;
  }

  // ============================================================================
  // 區塊 2：滑動視窗標準差輔助函式
  // ============================================================================
  List<double> _calculateMovstd(List<double> data, int windowSize) {
    int n = data.length;
    List<double> result = List.filled(n, 0.0);
    if (n == 0) return result;

    for (int i = 0; i < n; i++) {
      // MATLAB movstd 偶數視窗預設對齊方式：向前 n/2 - 1，向後 n/2
      int start = max(0, i - (windowSize ~/ 2 - 1));
      int end = min(n - 1, i + (windowSize ~/ 2));
      int count = end - start + 1;

      double sum = 0;
      for (int j = start; j <= end; j++) {
        sum += data[j];
      }
      double mean = sum / count;

      double variance = 0;
      for (int j = start; j <= end; j++) {
        variance += (data[j] - mean) * (data[j] - mean);
      }
      result[i] = count > 1 ? sqrt(variance / (count - 1)) : 0.0;
    }
    return result;
  }
}
