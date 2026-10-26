# models/ — 7 折模型

7 折留一受試者交叉驗證的 7 個模型。每個模型訓練時**排除一位受試者（3 筆資料）**，並用被排除的受試者測試。

| 檔案 | 訓練時排除（用來測試）的受試者 | 資料 | 大小 | 節點數 | 最大深度 |
|---|---|---|---|---|---|
| `model_fold1.json` | 受試者 1 | tug1～3 | 8.70 MB | 83,250 | 24 |
| `model_fold2.json` | 受試者 2 | tug4～6 | 9.11 MB | 87,150 | 26 |
| `model_fold3.json` | 受試者 3 | tug7～9 | 8.64 MB | 82,644 | 26 |
| `model_fold4.json` | 受試者 4 | tug10～12 | 9.00 MB | 85,998 | 26 |
| `model_fold5.json` | 受試者 5 | tug13～15 | 9.01 MB | 86,154 | 27 |
| `model_fold6.json` | 受試者 6 | tug16～18 | 9.47 MB | 90,520 | 27 |
| `model_fold7.json` | 受試者 7 | tug19～21 | 9.08 MB | 86,752 | 26 |

每個模型都是 500 棵樹；節點數為所有樹的分支節點加葉節點總和。

## 原檔名對照
匯出時的原檔名為 `model_1`、`model_2`、`model_3`、`model_4`、`model_5`、`model_7`、`model`。
其中原檔名 `model.json` 的內容是**第 6 折**（沒有 `model_6.json`），為了避免誤解，整理時一律改為 `model_fold{折號}.json`。

## App 目前使用哪一個
`app/assets/model.json` 與 `model_fold7.json` 的 MD5 相同（`c3404dc532f8137a5eeb8886c2178360`），
也就是 App 內建的是**第 7 折模型**（訓練時不含受試者 7 的資料）。使用全部 21 筆資料訓練的最終模型尚未產生。

## 折別如何判定
`evaluation/identify_model_folds.py` 讓每個模型預測全部 21 筆資料：沒看過的資料視窗準確率約 74～90%，
看過的約 99%。輸出見 `evaluation/identify_model_folds_output.txt`。

## 更換 App 模型的方法
1. 以 `model60Hz.m` 訓練並匯出 JSON
2. 複製到 `app/assets/model.json`（`pubspec.yaml` 已登記此資產）
3. 重新編譯 App

JSON 格式見 [`../../../docs/model_json_format.md`](../../../docs/model_json_format.md)。
