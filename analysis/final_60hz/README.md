# 最終版（60Hz）— 訓練、驗證與輸出

本資料夾對應 `app/` 的部署流程：資料由 App 錄製（Movella DOT，60Hz），模型在 MATLAB 訓練後匯出成 JSON，內建於 App。
舊版（128Hz 離線分析）請見 [`../legacy_128hz/`](../legacy_128hz/)，兩者不可混用。

## 內容

| 路徑 | 說明 |
|---|---|
| `model60Hz.m` | 訓練與驗證腳本：載入資料 → 70 通道 → 滑動視窗與 560 維特徵 → 7 折留一受試者 Random Forest → 匯出 JSON → 後處理 → 計算指標 |
| `TUG60Hz.csv` | 21 筆測試的動作時間表（秒，M0～M7） |
| `data/tug1～21.csv` | App 錄製並匯出的原始 IMU 資料（60Hz，Movella DOT 匯出格式，3 行表頭） |
| `labels/GroundTruth_Label_FS1～21.csv` | 逐點標準答案（0 靜止、1～6 六個階段） |
| `predictions/RawPred_TUG1～21.csv` | 各折模型的原始預測（視窗預測鋪回取樣點、21 點中位數濾波，尚未後處理） |
| `models/` | 7 折模型 JSON，對應關係見 [`models/README.md`](models/README.md) |
| `evaluation/` | 重算指標與判斷模型折別的腳本與輸出 |

## `model60Hz.m` 的主要設定
- 視窗 20 點、步長 10 點（`WS_list` 雖列出 20、25、30，但迴圈只執行第一個）
- 8 項特徵：平均、標準差、最大、最小、全距、jerk 標準差（相鄰取樣差的標準差）、偏態、峰態；特徵四捨五入到小數 5 位，與 App 對齊
- 訓練標籤 4→2、5→3、6→1，模型實際學習 0～3 四類；六階段由後處理依位置拆分
- Random Forest：500 棵、每片葉子至少 2 筆、每次分裂取 40 個特徵
- 中位數濾波 21 點；後處理門檻為 60Hz 版（碎片 80 點、強制轉身 50 點、坐下 85 點…）
- 每折訓練完輸出 `model_{折號}.json`，並輸出 `GroundTruth_Label_FS*.csv` 與 `RawPred_TUG*.csv`

## 重現
1. MATLAB：修改 `model60Hz.m` 開頭的資料路徑（原為作者本機路徑），再執行；各折結果會印在視窗中。
   未設定亂數種子，重跑會有小幅差異。
2. Python（只需 numpy）：`python evaluation/replay_eval.py` 以 `labels/`、`predictions/`、`data/` 重算指標與各階段時間誤差。

## 評估結果摘要
詳見 [`evaluation/results.md`](evaluation/results.md)（Python 重算）與 [`evaluation/results_matlab.md`](evaluation/results_matlab.md)（MATLAB 實跑驗證）。

| 評估條件 | Accuracy | Sensitivity | Precision | F1 |
|---|---|---|---|---|
| 嚴格逐點 | 85.2% | 80.7% | 82.5% | 0.808 |
| 允許動作邊界 ±0.10 秒 | 89.4% | 86.2% | 87.5% | 0.863 |
| 允許動作邊界 ±0.25 秒 | 93.4% | 91.7% | 92.2% | 0.916 |

指標以 0～6 共七類（含靜止 0）計算。`model60Hz.m` 內含邊界容忍的程式碼，目前 `Tolerance = 0`（即嚴格逐點）。
