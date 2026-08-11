import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RandomForestClassifier2 {
  List<dynamic>? _forest;
  Map<String, dynamic>? metrics;

  Future<void> loadModel() async {
    try {
      print("DEBUG: 開始讀取 assets/model.json...");
      final jsonString = await rootBundle.loadString('assets/model.json');

      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      print("DEBUG: JSON 解析成功，內含 Key: ${decoded.keys.toList()}");

      if (decoded.containsKey('trees')) {
        _forest = decoded['trees'];
        print("✅ 成功存入 _forest，樹的數量: ${_forest?.length}");
      } else {
        print("❌ 錯誤：JSON 裡找不到 'trees' 這個 Key！請檢查 MATLAB 匯出的名稱。");
      }

      if (decoded.containsKey('metrics')) {
        metrics = decoded['metrics'];
        print("📊 成功存入 metrics");
      }
    } catch (e) {
      print("❌ loadModel 發生異常: $e");
      rethrow;
    }
  }

  // 2. 執行預測 (輸出：動作類別 0~6)
  int predict(List<double> features) {
    if (_forest == null) throw Exception("模型尚未載入，請先呼叫 loadModel()");

    List<int> voteCounts = List.filled(7, 0);

    for (var tree in _forest!) {
      int prediction = _traverseTree(tree, features);
      if (prediction >= 0 && prediction < voteCounts.length) {
        voteCounts[prediction]++;
      }
    }

    // 對齊 MATLAB 平手機制：票數相同時保留數字較小的類別。
    int finalClass = 0;
    int maxVotes = -1;
    for (int i = 0; i < voteCounts.length; i++) {
      if (voteCounts[i] > maxVotes) {
        maxVotes = voteCounts[i];
        finalClass = i;
      }
    }
    return finalClass;
  }

  // 3. 遞迴遍歷決策樹 (邏輯與 MATLAB 端的 parseTree 對應)
  int _traverseTree(Map<String, dynamic> node, List<double> features) {
    if (node['isLeaf'] == true) {
      return (node['label'] as num).toInt();
    }

    // MATLAB 轉出時已減 1，此處直接使用 0-based 索引
    int featureIdx = (node['splitVarIdx'] as num).toInt();
    double threshold = (node['threshold'] as num).toDouble();

    if (features[featureIdx] < threshold) {
      return _traverseTree(node['left'], features);
    } else {
      return _traverseTree(node['right'], features);
    }
  }
}
