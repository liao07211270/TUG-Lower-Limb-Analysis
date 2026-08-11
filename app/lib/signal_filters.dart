/// 對齊 MATLAB medfilt1（奇數窗、邊界用可用樣本中位數）。
List<int> medianFilterIntLabels(List<int> data, int windowSize) {
  if (data.isEmpty) return [];
  final w = windowSize.isOdd ? windowSize : windowSize + 1;
  final half = w ~/ 2;
  final out = List<int>.filled(data.length, 0);
  for (int i = 0; i < data.length; i++) {
    final start = i - half < 0 ? 0 : i - half;
    final end = i + half >= data.length ? data.length - 1 : i + half;
    final slice = data.sublist(start, end + 1)..sort();
    out[i] = slice[slice.length ~/ 2];
  }
  return out;
}
