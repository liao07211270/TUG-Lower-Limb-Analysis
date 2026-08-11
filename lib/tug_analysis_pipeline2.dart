import 'data_processor.dart';
import 'feature_extractor2.dart';
import 'random_forest_classifier2.dart';
import 'post_processor2.dart';
import 'signal_filters.dart';

class TugResult {
  final double totalTime;
  final double standUpTime; // 1: 起立
  final double walkGoTime; // 2: 去程
  final double turn1Time; // 3: 轉身
  final double walkReturnTime; // 4: 回程
  final double turn2Time; // 5: 轉身準備坐下
  final double sitDownTime; // 6: 坐下

  TugResult({
    required this.totalTime,
    required this.standUpTime,
    required this.walkGoTime,
    required this.turn1Time,
    required this.walkReturnTime,
    required this.turn2Time,
    required this.sitDownTime,
  });
}

class TugAnalysisPipeline2 {
  final dataProcessor = TugDataProcessor();
  final featureExtractor = FeatureExtractor2();
  final randomForest = RandomForestClassifier2();
  final postProcessor = PostProcessor2();

  final double sampleRateHz = 60.0;
  final int windowSize = 20;

  Future<void> initModel() async {
    await randomForest.loadModel();
  }

  Future<TugResult> runAnalysis(List<List<dynamic>> csvFields) async {
    try {
      // 🌟 修正 3：在開始分析前，自動檢查並載入模型！
      print("🚀 [Pipeline] 0. 初始化載入 60Hz 隨機森林模型...");
      await initModel();

      print("🚀 [Pipeline] 1. 清洗資料...");
      List<List<double>> data70 = await dataProcessor.processFromFields(
        csvFields,
      );

      print("🚀 [Pipeline] 2. 擷取特徵...");
      List<List<double>> featureMatrix = featureExtractor.extract560Features(
        data70,
        windowSize,
      );

      print("🚀 [Pipeline] 3. 模型預測...");
      List<int> windowPredictions = [];
      for (var features in featureMatrix) {
        windowPredictions.add(randomForest.predict(features));
      }

      final step = featureExtractor.stepSize;

      // 對齊新訓練驗證流程：每個 window 預測覆寫完整 window 區間。
      int predLen = windowPredictions.isEmpty
          ? 0
          : windowSize + (windowPredictions.length - 1) * step;
      List<int> pointPredictions = List.filled(predLen, 0, growable: true);
      for (int j = 0; j < windowPredictions.length; j++) {
        int startIdx = j * step;
        int endIdx = startIdx + windowSize;
        for (int k = startIdx; k < endIdx; k++) {
          if (k < predLen) {
            pointPredictions[k] = windowPredictions[j];
          }
        }
      }
      while (pointPredictions.length < data70.length) {
        pointPredictions.add(
          pointPredictions.isEmpty ? 0 : pointPredictions.last,
        );
      }
      if (pointPredictions.length > data70.length) {
        pointPredictions = pointPredictions.sublist(0, data70.length);
      }

      // 60 Hz 模型輸出平滑，需與訓練/驗證時使用的後處理參數保持一致。
      pointPredictions = medianFilterIntLabels(pointPredictions, 21);

      print(
        '🚀 [Pipeline] RF 標籤分佈 (0~6): '
        '${_countLabels(pointPredictions, 0)} '
        '${_countLabels(pointPredictions, 1)} '
        '${_countLabels(pointPredictions, 2)} '
        '${_countLabels(pointPredictions, 3)} '
        '${_countLabels(pointPredictions, 4)} '
        '${_countLabels(pointPredictions, 5)} '
        '${_countLabels(pointPredictions, 6)}',
      );

      print("🚀 [Pipeline] 4. 物理規則後處理...");
      List<int> finalSegments = postProcessor.applyPhysicalRulesOnly(
        pointPredictions,
        data70,
      );

      print("🚀 [Pipeline] 5. 精算各階段時間...");
      int count1 = 0,
          count2 = 0,
          count3 = 0,
          count4 = 0,
          count5 = 0,
          count6 = 0;

      // 🌟 修正 2：真正的 TUG 總時間算法
      int firstActiveIdx = -1;
      int lastActiveIdx = -1;

      for (int i = 0; i < finalSegments.length; i++) {
        int label = finalSegments[i];
        if (label > 0) {
          // 只要不是 0 (靜止)，就視為動作中
          if (firstActiveIdx == -1) firstActiveIdx = i; // 記錄第一個動作點
          lastActiveIdx = i; // 不斷更新，直到最後一個動作點

          // 累加各階段點數
          if (label == 1)
            count1++;
          else if (label == 2)
            count2++;
          else if (label == 3)
            count3++;
          else if (label == 4)
            count4++;
          else if (label == 5)
            count5++;
          else if (label == 6)
            count6++;
        }
      }

      // 總時間 = (最後一個動作點 - 第一個動作點) / 60 Hz
      double totalTime = 0.0;
      if (firstActiveIdx != -1 && lastActiveIdx != -1) {
        totalTime = (lastActiveIdx - firstActiveIdx) / sampleRateHz;
      }

      double standUp = count1 / sampleRateHz;
      double walkGo = count2 / sampleRateHz;
      double turn1 = count3 / sampleRateHz;
      double walkReturn = count4 / sampleRateHz;
      double turn2 = count5 / sampleRateHz;
      double sitDown = count6 / sampleRateHz;

      print(
        '✅ [Pipeline] 完成 總:${totalTime.toStringAsFixed(1)}s '
        '起:$standUp 去:$walkGo 轉1:$turn1 回:$walkReturn 轉2:$turn2 坐:$sitDown',
      );
      print(
        '🚀 [Pipeline] 最終標籤 1~6: '
        '$count1 $count2 $count3 $count4 $count5 $count6',
      );

      return TugResult(
        totalTime: totalTime,
        standUpTime: standUp,
        walkGoTime: walkGo,
        turn1Time: turn1,
        walkReturnTime: walkReturn,
        turn2Time: turn2,
        sitDownTime: sitDown,
      );
    } catch (e) {
      print("❌ [Pipeline] 分析發生錯誤: $e");
      rethrow;
    }
  }

  int _countLabels(List<int> labels, int target) =>
      labels.where((l) => l == target).length;
}
