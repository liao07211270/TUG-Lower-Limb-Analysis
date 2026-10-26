"""
判斷每個模型 JSON 在交叉驗證中「沒看過哪位受試者」。

做法：讓 7 個折模型各自預測全部 21 筆資料（視窗層級，WS=20、SP=10，
特徵與投票方式與 App 相同）。沒看過的資料準確率會明顯低於看過的
（約 75~90% 對 99%）。只需要 numpy。

執行：python identify_model_folds.py
"""
import csv
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS, SP = 20, 10


def skew(d):
    m2 = ((d - d.mean()) ** 2).mean()
    return ((d - d.mean()) ** 3).mean() / m2 ** 1.5 if m2 > 0 else 0.0


def kurt(d):
    m2 = ((d - d.mean()) ** 2).mean()
    return ((d - d.mean()) ** 4).mean() / m2 ** 2 if m2 > 0 else 0.0


def features(i):
    """回傳 (560 維視窗特徵, 視窗標籤)；標籤 4→2、5→3、6→1，與訓練時相同。"""
    with open(os.path.join(ROOT, "data", f"tug{i}.csv"), encoding="utf-8", errors="ignore") as f:
        rows = [r for r in list(csv.reader(f))[3:] if r]
    groups = [range(1, 7), range(15, 21), range(29, 35), range(43, 49), range(57, 63)]
    raw = np.array([[float(r[c]) for g in groups for c in g] for r in rows])      # 30 通道
    two = []
    for j in range(0, 30, 3):
        a, b, c = raw[:, j], raw[:, j + 1], raw[:, j + 2]
        two += [np.sqrt(a * a + b * b), np.sqrt(a * a + c * c), np.sqrt(b * b + c * c)]
    three = [np.sqrt(raw[:, j] ** 2 + raw[:, j + 1] ** 2 + raw[:, j + 2] ** 2) for j in range(0, 30, 3)]
    X = np.column_stack([raw] + two + three)                                         # 70 通道
    gt = np.array([int(float(x)) for x in open(os.path.join(ROOT, "labels", f"GroundTruth_Label_FS{i}.csv")) if x.strip()])
    n = min(len(X), len(gt))
    X, gt = X[:n], gt[:n]
    F, Y = [], []
    for s in range(0, n - WS + 1, SP):
        w = X[s:s + WS]
        row = []
        for ch in range(70):
            d = w[:, ch]
            row += [d.mean(), d.std(ddof=1), d.max(), d.min(), d.max() - d.min(),
                    np.diff(d).std(ddof=1), skew(d), kurt(d)]
        F.append(row)
        v, c = np.unique(gt[s:s + WS], return_counts=True)
        Y.append({4: 2, 5: 3, 6: 1}.get(int(v[c == c.max()].min()), int(v[c == c.max()].min())))
    return np.round(np.nan_to_num(np.array(F)), 5), np.array(Y)


def flatten(tree):
    f, t, l, r, lab = [], [], [], [], []

    def add(n):
        k = len(f)
        f.append(0); t.append(0.0); l.append(-1); r.append(-1); lab.append(-1)
        if n["isLeaf"]:
            lab[k] = int(n["label"])
        else:
            f[k] = int(n["splitVarIdx"]); t[k] = float(n["threshold"])
            l[k] = add(n["left"]); r[k] = add(n["right"])
        return k

    add(tree)
    return np.array(f), np.array(t), np.array(l), np.array(r), np.array(lab)


def predict(trees, F):
    votes = np.zeros((len(F), 4), int)
    idx = np.arange(len(F))
    for f, t, l, r, lab in trees:
        node = np.zeros(len(F), int)
        for _ in range(80):
            leaf = lab[node] >= 0
            if leaf.all():
                break
            go = np.where(F[idx, f[node]] < t[node], l[node], r[node])   # 小於門檻往左
            node = np.where(leaf, node, go)
        votes[idx, lab[node]] += 1                                       # 每棵樹投一票
    return votes.argmax(1)


def main():
    data = {i: features(i) for i in range(1, 22)}
    print("每格 = 該模型對該筆資料的視窗層級準確率 (%)，* = 該折應該沒看過")
    print("model        " + " ".join(f"{i:3d}" for i in range(1, 22)) + " | 沒看過平均  看過平均")
    for k in range(1, 8):
        name = f"model_fold{k}"
        with open(os.path.join(ROOT, "models", name + ".json"), encoding="utf-8") as fh:
            trees = [flatten(t) for t in json.load(fh)["trees"]]
        accs = np.array([(predict(trees, data[i][0]) == data[i][1]).mean() * 100 for i in range(1, 22)])
        held = list(range(3 * k - 3, 3 * k))
        others = [j for j in range(21) if j not in held]
        cells = " ".join((f"{a:3.0f}" + ("*" if j in held else " "))[:4] for j, a in enumerate(accs))
        print(f"{name:12s} {cells} | {accs[held].mean():5.1f}      {accs[others].mean():5.1f}")


if __name__ == "__main__":
    main()
