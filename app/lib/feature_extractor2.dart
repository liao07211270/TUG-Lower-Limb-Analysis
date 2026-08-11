import 'dart:math';

class FeatureExtractor2 {
  final int stepSize = 10; // SP = 10

  List<List<double>> extract560Features(List<List<double>> data70, int ws) {
    List<List<double>> featureMatrix = [];
    // 確保 start + ws 不會超出數據長度
    for (int start = 0; start <= data70.length - ws; start += stepSize) {
      List<double> rowFeatures = [];
      for (int ch = 0; ch < 70; ch++) {
        List<double> segment = [];
        for (int i = start; i < start + ws; i++) {
          segment.add(data70[i][ch]);
        }
        rowFeatures.addAll(_calculate8Stats(segment));
      }
      featureMatrix.add(rowFeatures);
    }
    return featureMatrix;
  }

  List<double> _calculate8Stats(List<double> data) {
    int n = data.length;
    double nDouble = n.toDouble();
    double mean = data.reduce((a, b) => a + b) / nDouble;

    double sumSqDiff = 0;
    double sumCubeDiff = 0;
    double sumQuadDiff = 0;
    double maxVal = data[0];
    double minVal = data[0];

    for (var x in data) {
      double diff = x - mean;
      double diffSq = diff * diff;
      sumSqDiff += diffSq;
      sumCubeDiff += diffSq * diff;
      sumQuadDiff += diffSq * diffSq;

      if (x > maxVal) maxVal = x;
      if (x < minVal) minVal = x;
    }

    // 1. Variance (MATLAB var 預設是除以 n-1)
    double variance = sumSqDiff / (nDouble - 1);

    // 2. Standard Deviation (MATLAB std 預設是除以 n-1)
    double std = sqrt(variance);

    List<double> jerkData = [];
    for (int i = 0; i < n - 1; i++) {
      jerkData.add(data[i + 1] - data[i]);
    }
    double jerkMean = jerkData.reduce((a, b) => a + b) / (nDouble - 1);
    double jerkSumSqDiff = 0;
    for (var j in jerkData) {
      double jDiff = j - jerkMean;
      jerkSumSqDiff += jDiff * jDiff;
    }
    double jerkStd = sqrt(jerkSumSqDiff / (nDouble - 2));

    // --- 以下為對齊 MATLAB 預設 skewness/kurtosis (Biased 模式) ---
    // 計算二階、三階、四階中心動差 (m2, m3, m4)
    double m2 = sumSqDiff / nDouble;
    double m3 = sumCubeDiff / nDouble;
    double m4 = sumQuadDiff / nDouble;

    // 3. Skewness (MATLAB 預設: m3 / m2^1.5)
    double skew = 0;
    if (m2 > 0) {
      skew = m3 / pow(m2, 1.5);
    }

    // 4. Kurtosis (MATLAB 預設: m4 / m2^2，且不減 3)
    double kurt = 0;
    if (m2 > 0) {
      kurt = m4 / (m2 * m2);
    }

    List<double> rawFeatures = [
      mean, // 1. mean
      std, // 2. std
      maxVal, // 3. max
      minVal, // 4. min
      maxVal - minVal, // 5. range
      jerkStd.isNaN ? 0.0 : jerkStd, // 6. jerk std
      skew.isNaN ? 0.0 : skew, // 7. skewness
      kurt.isNaN ? 0.0 : kurt, // 8. kurtosis
    ];

    return rawFeatures.map((v) => double.parse(v.toStringAsFixed(5))).toList();
  }
}
