"""
重算最終版（60Hz）的評估結果。

輸入（皆為本資料夾上一層已存在的檔案）：
  ../data/tug{1..21}.csv                原始 IMU 資料（App 錄製、60Hz）
  ../labels/GroundTruth_Label_FS*.csv   逐點標準答案（0~6）
  ../predictions/RawPred_TUG*.csv       model60Hz.m 輸出、尚未後處理的預測（含 21 點中位數濾波）

做的事：
  1. 把 model60Hz.m 的「後處理」逐步移植成 Python（參數與 model60Hz.m 相同）。
  2. 依 7 折留一受試者（每人 3 筆）計算 Accuracy / Sensitivity / Precision / F1，
     分成「嚴格逐點」與「允許邊界容忍 ±N 點」兩種條件。
  3. 計算 App 實際輸出的「各階段時間」與標準答案的誤差（秒）。

執行：python replay_eval.py          （只需要 numpy）
"""
import csv
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FS = 60  # 取樣率 (Hz)


# ----------------------------------------------------------------------------
# 讀檔
# ----------------------------------------------------------------------------
def load(i):
    """回傳 (第一顆感測器加速度合成, 標準答案, 原始預測)。

    model60Hz.m 的 Raw_Acc 是 AccGyro 第 61 欄，也就是第一顆感測器（左小腿）
    X、Y、Z 加速度的合成值；CSV 前三行是表頭，第 2~4 欄是 X、Y、Z。
    """
    with open(os.path.join(ROOT, "data", f"tug{i}.csv"), encoding="utf-8", errors="ignore") as f:
        rows = [r for r in list(csv.reader(f))[3:] if r]
    acc = np.array([[float(r[1]), float(r[2]), float(r[3])] for r in rows])
    gt = np.array([int(float(x)) for x in open(os.path.join(ROOT, "labels", f"GroundTruth_Label_FS{i}.csv")) if x.strip()])
    pr = np.array([int(float(x)) for x in open(os.path.join(ROOT, "predictions", f"RawPred_TUG{i}.csv")) if x.strip()])
    n = min(len(acc), len(gt), len(pr))
    return np.linalg.norm(acc, axis=1)[:n], gt[:n], pr[:n]


# ----------------------------------------------------------------------------
# 後處理（對應 model60Hz.m 第 218~427 行）
# ----------------------------------------------------------------------------
def movstd(x, w):
    """MATLAB movstd：偶數視窗為前 w/2、後 w/2-1，邊界縮小。"""
    n = len(x)
    out = np.zeros(n)
    for i in range(n):
        seg = x[max(0, i - w // 2): min(n - 1, i + w // 2 - 1) + 1]
        out[i] = seg.std(ddof=1) if len(seg) > 1 else 0.0
    return out


def runs(mask):
    out, i, n = [], 0, len(mask)
    while i < n:
        if mask[i]:
            j = i
            while j + 1 < n and mask[j + 1]:
                j += 1
            out.append((i, j))
            i = j + 1
        else:
            i += 1
    return out


def longest_turn_end(seg, limit):
    """limit 之前最長一段「轉身(3)」的結尾索引；沒有則回傳 None。"""
    valid = [i for i in np.nonzero(seg == 3)[0] if i < limit]
    if not valid:
        return None
    best, best_len, cur = None, 0, [valid[0]]
    groups = []
    for a in valid[1:]:
        if a - cur[-1] == 1:
            cur.append(a)
        else:
            groups.append(cur)
            cur = [a]
    groups.append(cur)
    for g in groups:
        if len(g) > best_len:
            best_len, best = len(g), g
    return best[-1]


def post_process(seg, std):
    seg = seg.copy()
    n = len(seg)
    for s, e in runs(seg != 0):          # 移除短於 80 點的碎片
        if e - s + 1 < 80:
            seg[s:e + 1] = 0
    act = np.nonzero(seg != 0)[0]
    model_end, active_start = (act[-1], act[0]) if len(act) else (n - 1, 0)
    sit_count = int((seg[max(0, model_end - 200): model_end + 1] == 1).sum())

    if sit_count > 2:                    # 分支 1：正常坐下
        active_end = model_end
        for ext in range(1, 61):         # 與 model60Hz.m 相同：索引為 active_end + ext
            ci = active_end + ext
            if ci > n - 1:
                break
            if std[ci] < 0.10:
                seg[ci] = 1
                active_end = ci
            else:
                break
        sit = np.nonzero(seg == 1)[0]
        last_sit_start = n - 1
        if len(sit):
            br = np.nonzero(np.diff(sit) > 1)[0]
            last_sit_start = sit[br[-1] + 1] if len(br) else sit[0]
        force_end = last_sit_start - 1
        force_start = max(0, last_sit_start - 50)
        for sh in range(0, 50 - 14 + 1):
            c = force_start + sh
            if c < n and std[c] < 0.15:
                force_start = c
                break
        force_end = min(force_end, active_end)
        if force_end > force_start:
            seg[force_start:force_end + 1] = 3
        if last_sit_start < active_end:
            seg[last_sit_start:active_end + 1] = 1
        if active_end < n - 1:
            seg[active_end + 1:] = 0
        split = int(math.floor(n / 2 + 0.5)) - 1
        e = longest_turn_end(seg, force_start)
        if e is not None:
            split = e
        if force_start > split:
            for k in range(split + 1, force_start):
                if seg[k] == 1:
                    seg[k] = 2
    else:                                # 分支 2：異常救回
        hi = np.nonzero(std > 0.10)[0]
        walk_end = hi[-1] if len(hi) else model_end
        active_end = min(n - 1, walk_end + 60)
        if active_end < n - 1:
            seg[active_end + 1:] = 0
        if walk_end < active_end:
            seg[walk_end + 1:active_end + 1] = 1
        turn_start = max(active_start, walk_end - 30 + 1)
        if walk_end > turn_start:
            seg[turn_start:walk_end + 1] = 3
        force_start = turn_start
        split = int(math.floor(n / 2 + 0.5)) - 1
        e = longest_turn_end(seg, force_start)
        if e is not None:
            split = e
        if force_start > split:
            seg[split + 1:force_start] = 2

    for k in range(split + 1, active_end + 1):   # 後半段 2/1/3 → 4/6/5
        v = seg[k]
        seg[k] = 4 if v == 2 else 6 if v == 1 else 5 if v == 3 else v
    for k in range(active_start, split + 1):     # 前半段防呆
        if seg[k] >= 4:
            seg[k] -= 3
    for s, e in runs(seg != 0):                  # 最後移除短於 20 點的碎片
        if e - s + 1 < 20:
            seg[s:e + 1] = 0
    return seg


# ----------------------------------------------------------------------------
# 指標
# ----------------------------------------------------------------------------
def relax(gt, pred, tol):
    """邊界容忍：標準答案切換點 ±tol 點內，預測屬於交界合法動作者視為正確。"""
    if tol <= 0:
        return pred
    r, n = pred.copy(), len(gt)
    d = np.diff(np.concatenate([[0], gt, [0]]))
    for idx in np.nonzero(d != 0)[0] + 1:                # 1-based
        s, e = max(1, idx - tol), min(n, idx + tol)
        valid = set(gt[s - 1:e].tolist())
        for w in range(s, e + 1):
            if r[w - 1] in valid:
                r[w - 1] = gt[w - 1]
    return r


def metrics(gt, pred):
    C = np.zeros((7, 7), int)
    for a, b in zip(gt, pred):
        C[a, b] += 1
    acc = np.trace(C) / C.sum()
    sen = np.array([C[k, k] / C[k].sum() if C[k].sum() else np.nan for k in range(7)])
    pre = np.array([C[k, k] / C[:, k].sum() if C[:, k].sum() else np.nan for k in range(7)])
    f1 = np.array([2 * pre[k] * sen[k] / (pre[k] + sen[k]) if (pre[k] + sen[k]) > 0 else np.nan for k in range(7)])
    return acc, np.nanmean(sen), np.nanmean(pre), np.nanmean(f1)


def main():
    final = {i: None for i in range(1, 22)}
    gts = {}
    for i in range(1, 22):
        acc, gt, pr = load(i)
        final[i] = post_process(pr.astype(int), movstd(acc, 24))
        gts[i] = gt

    print("## 評估條件")
    print("- 資料：21 筆 App 錄製（60Hz），7 位受試者 × 3 次")
    print("- 驗證：7 折留一受試者；指標為 0~6 共七類（含靜止 0），各折計算後取平均")
    print("- 後處理：與 model60Hz.m 相同\n")

    print("## 逐點分類指標（依邊界容忍分組）\n")
    print("| 邊界容忍 | Accuracy | Sensitivity | Precision | F1 |")
    print("|---|---|---|---|---|")
    for tol in (0, 6, 15, 30):
        res = []
        for b in range(7):
            ids = (3 * b + 1, 3 * b + 2, 3 * b + 3)
            g = np.concatenate([gts[i] for i in ids])
            p = relax(g, np.concatenate([final[i] for i in ids]), tol)
            res.append(metrics(g, p))
        r = np.array(res)
        label = "嚴格逐點（±0）" if tol == 0 else f"±{tol} 點（±{tol / FS:.2f} 秒）"
        print(f"| {label} | {r[:, 0].mean() * 100:.1f}% | {r[:, 1].mean() * 100:.1f}% | {r[:, 2].mean() * 100:.1f}% | {r[:, 3].mean():.3f} |")

    names = ["起立", "去程", "轉身", "回程", "轉身（準備坐下）", "坐下"]

    def durations(x):
        d = {k: (x == k).sum() / FS for k in range(1, 7)}
        nz = np.nonzero(x != 0)[0]
        d["total"] = (nz[-1] - nz[0]) / FS if len(nz) else 0.0
        return d

    err = {k: [] for k in list(range(1, 7)) + ["total"]}
    for i in range(1, 22):
        g, p = durations(gts[i]), durations(final[i])
        for k in err:
            err[k].append(p[k] - g[k])

    print("\n## 各階段時間誤差（預測 − 標準答案，21 筆）\n")
    print("| 項目 | 平均絕對誤差 | 平均偏差 | 最大絕對誤差 |")
    print("|---|---|---|---|")
    for k in range(1, 7):
        e = np.array(err[k])
        print(f"| {names[k - 1]} | {np.abs(e).mean():.2f} 秒 | {e.mean():+.2f} 秒 | {np.abs(e).max():.2f} 秒 |")
    e = np.array(err["total"])
    print(f"| **總時間** | {np.abs(e).mean():.2f} 秒 | {e.mean():+.2f} 秒 | {np.abs(e).max():.2f} 秒 |")


if __name__ == "__main__":
    main()
