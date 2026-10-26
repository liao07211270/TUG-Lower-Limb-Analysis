# 模型 JSON 格式與 App 的接法

## 1. MATLAB 匯出（`analysis/final_60hz/model60Hz.m`）
`saveForestToJSON(model, filename)` 對 `model.Trained{i}`（第 i 棵樹）呼叫 `parseTree` 遞迴轉換，再 `jsonencode`，
並把所有小數固定成 15 位，避免精度流失。

單一節點的欄位：

| 欄位 | 說明 |
|---|---|
| `isLeaf` | 是否為葉節點 |
| `label` | 葉節點的類別（0 靜止、1 起立或坐下、2 走路、3 轉身）；分支節點為 -1 |
| `splitVarIdx` | 分裂用的特徵索引（0 起算，範圍 0～559） |
| `threshold` | 門檻；特徵值**小於**門檻走 `left`，否則走 `right` |
| `left`／`right` | 左、右子樹 |

整個檔案是 `{"trees": [樹1, 樹2, …, 樹500]}`。

> 目前 `model60Hz.m` 的 `parseTree` 另外匯出葉節點的 `probabilities`（各類別機率），
> 但現有 JSON 沒有這個欄位，App 也不讀取。

## 2. 特徵索引如何解讀
索引 ＝ `通道 × 8 ＋ 統計量`（通道、統計量皆從 0 起算）。

- 統計量順序：0 平均、1 標準差、2 最大、3 最小、4 全距、5 jerk 標準差、6 偏態、7 峰態
- 通道順序（共 70）：
  - 1～30 原始通道，依序為左小腿（1–6）、右小腿（7–12）、左大腿（13–18）、右大腿（19–24）、腰部（25–30），每顆為加速度 X、Y、Z、角速度 X、Y、Z
  - 31～60 兩軸合成（每顆 6 個：加速度 XY、XZ、YZ，角速度 XY、XZ、YZ）
  - 61～70 三軸合成（每顆 2 個：加速度、角速度）
- 例：索引 162 ＝ 通道 21（右大腿加速度 Z）的最大值

## 3. App 載入與預測（`app/lib/`）
1. `pubspec.yaml` 登記 `assets/model.json`，編譯時內建於 App
2. `random_forest_classifier2.dart`：`rootBundle.loadString` → `jsonDecode` → 保存 `trees`
   （目前每次分析都重新載入，未快取）
3. `feature_extractor2.dart`：計算 560 維特徵（視窗 20、步長 10），順序與 MATLAB 一致
4. 預測：每棵樹從根節點走到葉節點，每棵樹投一票，得票最多的類別為結果，同票取編號較小者
5. `tug_analysis_pipeline2.dart`：視窗預測鋪回取樣點 → 21 點中位數濾波 → `post_processor2.dart`
   後處理拆成六階段 → 以 60Hz 換算各階段時間

## 4. 與 MATLAB 對齊的處理
- 特徵數值四捨五入到小數 5 位
- 偏態、峰態採有偏公式（與 MATLAB 預設相同）
- 中位數濾波的邊界處理對齊 `medfilt1`
- 同票時取編號較小的類別

## 5. 已知差異
- MATLAB `fitcensemble`（Bag）預設以各樹葉節點的類別機率平均來決定類別，App 採每棵樹一票的投票，
  兩者在少數視窗上可能不同
- 後處理在 MATLAB 與 Dart 之間有兩處寫法不同（坐下延伸的索引、`movstd` 偶數視窗的對齊方向），影響約 0.1%
