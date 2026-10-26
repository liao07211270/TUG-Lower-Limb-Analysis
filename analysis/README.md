# analysis/

| 資料夾 | 版本 | 取樣率 | 資料來源 | 說明 |
|---|---|---|---|---|
| [`final_60hz/`](final_60hz/) | **最終版** | 60Hz | 本專題 App 錄製（Movella DOT） | 與 `app/` 部署流程對應 |
| [`legacy_128hz/`](legacy_128hz/) | **舊版（保留，僅供對照）** | 128Hz | `20251118-FS*.csv` | 離線 MATLAB 分析；結果不代表 App 部署參數 |

兩版的參數、特徵與後處理門檻都不同，詳見 [`../docs/comparison_legacy_vs_final.md`](../docs/comparison_legacy_vs_final.md)。
