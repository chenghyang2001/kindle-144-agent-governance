#!/bin/bash
# K144 第 3 章互動演練：分散決策與專家代理——交叉驗證、置信閾、決策拍賣與連鎖簽名，一次跑一步
# 用法：bash ch03.sh <步驟 1-8>
# 呼叫模型：只有第 7 步會呼叫模型 1 次（llm_agent.ask_json，走 claude -p，最多 180 秒）；其他 7 步全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch03/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K144 第 3 章｜分散決策與專家代理　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "單一視角 vs 三專家交叉驗證"
   tip "存貨週轉率下降，真正原因可能是淡季、原料漲價先囤貨、同業普遍下滑，或真的效率改善。通用模型答對 60%、答錯照常輸出；三個專家各自答對 80%，兩票以上一致才採用，否則上報人工。每筆靜默錯誤假設影響 3 萬元備料。"
   P='import random

random.seed(144)
N = 1000
ANSWERS = ["淡季正常波動", "原料漲價先囤貨", "同業普遍下滑", "營運效率改善"]
GEN_ACC, EXP_ACC, LOSS = 0.60, 0.80, 3
EXPERTS = ["季節性專家", "原料價格專家", "同業比較專家"]

def answer(truth, acc):
    if random.random() < acc:
        return truth
    return random.choice([a for a in ANSWERS if a != truth])

stats = {"gen": [0, 0, 0], "panel": [0, 0, 0]}      # 自動答對、靜默答錯、上報人工
calls = {"gen": 0, "panel": 0}
example = None
for _ in range(N):
    truth = random.choice(ANSWERS)
    g = answer(truth, GEN_ACC)
    calls["gen"] += 1
    stats["gen"][0 if g == truth else 1] += 1
    votes = [answer(truth, EXP_ACC) for _ in EXPERTS]
    calls["panel"] += len(EXPERTS)
    best = max(ANSWERS, key=votes.count)
    if votes.count(best) >= 2:
        stats["panel"][0 if best == truth else 1] += 1
    else:
        stats["panel"][2] += 1                       # 三方各說各話：上報人工
        if example is None:
            example = (truth, votes)

print("【開場案例】存貨週轉率下降：背後真正的原因有 4 種可能，模擬 1,000 個案例")
print(f"單一通用模型：答對率 {GEN_ACC:.0%}，答錯也照常輸出")
print(f"3 個專家代理：各自答對率 {EXP_ACC:.0%}，2 票以上一致才採用，否則上報人工")
print(f"假設每筆靜默錯誤影響 {LOSS} 萬元備料決策")
print()
print(" 做法            | 模型呼叫 | 自動答對 | 靜默答錯 | 上報人工 | 靜默錯誤影響備料")
print("-" * 84)
for key, name in (("gen", "單一通用模型"), ("panel", "3 專家交叉驗證")):
    ok, wrong, esc = stats[key]
    print(f" {name:<14} | {calls[key]:>8,} | {ok:>8} | {wrong:>8} | {esc:>8} | {wrong * LOSS:>10,} 萬元")
print()
if example:
    truth, votes = example
    print("分歧的例子（會上報給人）：")
    for e, v in zip(EXPERTS, votes):
        print(f"  {e}：{v}")
    print(f"  （真正原因：{truth}）")
print()
ratio = calls["panel"] // calls["gen"]
print("單一視角錯了不會報錯，只會安靜地把錯誤送進下游；交叉驗證把「錯」變成「分歧」，分歧才有機會被人看見。")
print(f"代價：模型呼叫變成 {ratio} 倍——所以要在「可控的成本與風險框架」下協作，而不是無限加專家。")'
   show "$P"; run "$P" ;;
2) banner "領域微調 vs 動態檢索：依任務路由"
   tip "三種任務各跑 12 個月。微調：領域內答對 93%、跨領域只有 60%、0.4 秒、每 3 個月重訓一次（每次 300 單位），重訓之間規則變動會讓答對率逐月打折。檢索：領域內 88%、跨領域 85%、1.2 秒、不受規則變動影響。這一步沒有亂數，數字每次都一樣。"
   P='MONTHS = 12
FT = {"domain": 0.93, "general": 0.60, "latency": 0.4, "per_call": 0.001, "retrain": 300, "every": 3}
RAG = {"domain": 0.88, "general": 0.85, "latency": 1.2, "per_call": 0.004, "index": 5}

def make_tasks(drift_a):
    return [
        ("A 發票科目分類（高頻穩定）", 20000, drift_a, True),
        ("B 新法規條文比對（低頻多變）", 500, 0.15, True),
        ("C 跨部門臨時問答（通用）", 2000, 0.0, False),
    ]

def errors(mode, n, drift, domain):
    if mode == "RAG":
        acc = RAG["domain"] if domain else RAG["general"]
        return n * MONTHS * (1 - acc)
    total = 0.0
    for m in range(MONTHS):
        acc = FT["domain"] * (1 - drift) ** (m % FT["every"]) if domain else FT["general"]
        total += n * (1 - acc)
    return total

def evaluate(plan, tasks):
    err = cost = lat = calls = 0.0
    for name, n, drift, domain in tasks:
        mode, k = plan[name], n * MONTHS
        cfg = FT if mode == "FT" else RAG
        err += errors(mode, n, drift, domain)
        cost += k * cfg["per_call"]
        lat += k * cfg["latency"]
        calls += k
    modes = set(plan.values())
    if "FT" in modes:
        cost += FT["retrain"] * (MONTHS // FT["every"])
    if "RAG" in modes:
        cost += RAG["index"] * MONTHS
    return err, cost, lat / calls

def router(tasks):
    return {name: min(("FT", "RAG"), key=lambda m: errors(m, n, d, dom)) for name, n, d, dom in tasks}

def report(drift_a):
    tasks = make_tasks(drift_a)
    plan = router(tasks)
    print(f"【任務 A 每月規則變動 {drift_a:.0%}】12 個月的期望錯誤數")
    print(" 任務                         | 每月次數 | 微調錯誤 | 檢索錯誤 | 路由選擇")
    print("-" * 80)
    for name, n, d, dom in tasks:
        ef, er = errors("FT", n, d, dom), errors("RAG", n, d, dom)
        choice = "領域微調" if plan[name] == "FT" else "動態檢索"
        print(f" {name:<22} | {n:>8,} | {ef:>8,.0f} | {er:>8,.0f} | {choice}")
    print()
    print(" 策略       | 年度錯誤 | 年度成本（單位） | 平均延遲（秒）")
    print("-" * 60)
    all_ft = {t[0]: "FT" for t in tasks}
    all_rag = {t[0]: "RAG" for t in tasks}
    for label, p in (("全部微調", all_ft), ("全部檢索", all_rag), ("依任務路由", plan)):
        e, c, l = evaluate(p, tasks)
        print(f" {label:<8} | {e:>8,.0f} | {c:>16,.0f} | {l:>14.2f}")
    print()
    return plan

print("微調：領域 93%／通用 60%／0.4 秒／每 3 個月重訓 300 單位；檢索：領域 88%／通用 85%／1.2 秒／索引每月 5 單位")
print()
p1 = report(0.01)
p2 = report(0.08)
a_name = make_tasks(0.01)[0][0]
before = "微調" if p1[a_name] == "FT" else "檢索"
after = "微調" if p2[a_name] == "FT" else "檢索"
print(f"任務 A 的規則每月變動從 1% 變成 8%：路由從「{before}」換成「{after}」。")
print("高頻穩定的任務適合微調；低頻多變、跨領域的任務適合檢索。路由的代價是兩套都要養，所以成本最高——用成本換更少的錯。")'
   show "$P"; run "$P" ;;
3) banner "練習 1A：置信閾曲線＋分級門檻"
   tip "5,000 筆決策，20% 是不可逆的（轉帳、處方、簽約）。置信度 c ~ Beta(5,2)，代理答對機率 = c；c 低於門檻就上報給人（人一定答對，每筆 1 個人工單位）。最後一張理論表假設人工成本 3、可逆錯誤 7.5、不可逆錯誤 20。結果寫到 ch03/interactive/threshold_auction.csv。"
   rm -f "$WORK/threshold_auction.csv"
   P='import csv
import os
import random

random.seed(144)
OUT = "ch03/interactive"
PATH = os.path.join(OUT, "threshold_auction.csv")
os.makedirs(OUT, exist_ok=True)
HEADER = ["section", "name", "human_units", "auto_errors", "irreversible_errors", "wins", "net_profit", "misallocation"]
N = 5000
recs = []
for _ in range(N):
    irr = random.random() < 0.20
    c = random.betavariate(5, 2)
    ok = random.random() < c
    recs.append((irr, c, ok))
n_irr = sum(1 for r in recs if r[0])

def run(t_rev, t_irr):
    esc = err = irr_err = 0
    for irr, c, ok in recs:
        if c < (t_irr if irr else t_rev):
            esc += 1                       # 上報給人：人一定答對
        elif not ok:
            err += 1                       # 自動執行卻答錯
            if irr:
                irr_err += 1
    return esc, err, irr_err

def row(name, esc, err, ie):
    return {"section": "threshold", "name": name, "human_units": esc, "auto_errors": err,
            "irreversible_errors": ie, "wins": "", "net_profit": "", "misallocation": ""}

print(f"{N:,} 筆決策（不可逆 {n_irr:,} 筆）；c ~ Beta(5,2)，答對機率 = c；c < 門檻 → 上報給人（每筆 1 個人工單位）")
print()
print("    t | 上報率 | 自動執行錯誤 | 其中不可逆 | 人工單位")
print("-" * 56)
rows = []
for i in range(10):
    t = round(0.50 + 0.05 * i, 2)
    esc, err, ie = run(t, t)
    print(f" {t:.2f} | {esc / N:>6.1%} | {err:>12,} | {ie:>10} | {esc:>8,}")
    rows.append(row("t=" + format(t, ".2f"), esc, err, ie))

single = run(0.70, 0.70)
tiered = run(0.60, 0.85)
print()
print(" 策略                       | 人工單位 | 可逆錯誤 | 不可逆錯誤")
print("-" * 64)
for name, (esc, err, ie) in (("單一門檻 0.7", single), ("分級：可逆 0.6／不可逆 0.85", tiered)):
    print(f" {name:<24} | {esc:>8,} | {err - ie:>8} | {ie:>10}")
rows.append(row("single_0.7", *single))
rows.append(row("tiered_0.6_0.85", *tiered))

HUMAN, E_REV, E_IRR = 3.0, 7.5, 20.0
def esc_p(t):
    return 6 * t ** 5 - 5 * t ** 6                                   # Beta(5,2) 的 CDF
def err_p(t):
    return 2 / 7 - (6 * t ** 5 - 10 * t ** 6 + 30 / 7 * t ** 7)       # c ≥ t 且答錯的機率
ts = [round(0.50 + 0.05 * i, 2) for i in range(10)]
cr = {t: HUMAN * esc_p(t) + E_REV * err_p(t) for t in ts}
ci = {t: HUMAN * esc_p(t) + E_IRR * err_p(t) for t in ts}
br, bi = min(cr, key=cr.get), min(ci, key=ci.get)
print()
print(f"【理論曲線】每筆期望成本 = 人工 {HUMAN:g} × 上報機率 + 錯誤成本 × 自動錯誤機率（可逆錯誤 {E_REV:g}、不可逆錯誤 {E_IRR:g}）")
print("    t | 可逆類每筆成本 | 不可逆類每筆成本")
print("-" * 44)
for t in ts:
    m1 = " ←最低" if t == br else "      "
    m2 = " ←最低" if t == bi else ""
    print(f" {t:.2f} | {cr[t]:>12.3f}{m1} | {ci[t]:>12.3f}{m2}")
t_rev, t_irr = 1 - HUMAN / E_REV, 1 - HUMAN / E_IRR
print(f"理論最佳門檻 = 1 − 人工成本／錯誤成本：可逆 {t_rev:.2f}、不可逆 {t_irr:.2f}（與表中最低點一致）")

with open(PATH, "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=HEADER)
    w.writeheader()
    w.writerows(rows)
print()
print("已寫入", PATH, f"（{len(rows)} 列門檻資料；拍賣資料第 4 步補上）")'
   show "$P"; run "$P" ;;
4) banner "練習 1B＋C：密封第二價格拍賣"
   tip "5 個專家代理，綜合分 = 0.5×成功率 + 0.3×(1−成本/10) + 0.2×(1−延遲/5)，分數最高者得標。E 只改自己報的成本（−40%～+40%）。first_price：報酬＝E 自己報的成本；second_price：報酬＝「讓 E 的分數剛好等於第二名」的成本。同一個報價偏差下，兩種規則誰得標完全一樣，差的只是付多少錢。這一步會讀第 3 步的 CSV 並補上拍賣列。"
   P='import csv
import os
import random

random.seed(144)
OUT = "ch03/interactive"
PATH = os.path.join(OUT, "threshold_auction.csv")
os.makedirs(OUT, exist_ok=True)
HEADER = ["section", "name", "human_units", "auto_errors", "irreversible_errors", "wins", "net_profit", "misallocation"]
COST_MAX, LAT_MAX, ROUNDS = 10.0, 5.0, 1000
AGENTS = {                     # 真實成本, 延遲秒數, 歷史成功率
    "A": (6.0, 2.0, 0.92),
    "B": (4.0, 3.0, 0.85),
    "C": (8.0, 1.0, 0.95),
    "D": (3.0, 4.0, 0.78),
    "E": (5.0, 2.5, 0.88),
}
LIES = [-0.4, -0.2, 0.0, 0.2, 0.4]
rounds = []
for _ in range(ROUNDS):
    rounds.append({k: (c * random.uniform(0.9, 1.1), l * random.uniform(0.9, 1.1), min(0.99, s * random.uniform(0.9, 1.1)))
                   for k, (c, l, s) in AGENTS.items()})

def score(c, l, s):
    return 0.5 * s + 0.3 * (1 - c / COST_MAX) + 0.2 * (1 - l / LAT_MAX)

def cost_for_score(target, l, s):
    # 在延遲、成功率不變下，讓分數剛好等於 target 的「成本」
    return COST_MAX * (1 - (target - 0.5 * s - 0.2 * (1 - l / LAT_MAX)) / 0.3)

def auction(lie, rule):
    wins, profit, mis = 0, 0.0, 0
    for r in rounds:
        true_scores = {k: score(*v) for k, v in r.items()}
        bids = {}
        for k, (c, l, s) in r.items():
            rep = c * (1 + lie) if k == "E" else c
            bids[k] = score(rep, l, s)
        ranked = sorted(bids, key=bids.get, reverse=True)
        w, second = ranked[0], ranked[1]
        if w != max(true_scores, key=true_scores.get):
            mis += 1                                    # 得標者不是真實最佳代理
        if w == "E":
            wins += 1
            c, l, s = r["E"]
            pay = c * (1 + lie) if rule == "first_price" else cost_for_score(bids[second], l, s)
            profit += pay - c
    return wins, profit, mis

print("5 個專家代理（每輪成本、延遲、成功率各隨機擾動 ±10%）")
print(" 代理 | 真實成本 | 延遲(秒) | 歷史成功率 | 平均綜合分")
print("-" * 54)
for k, (c, l, s) in AGENTS.items():
    print(f"  {k}   | {c:>8.1f} | {l:>8.1f} | {s:>10.2f} | {score(c, l, s):>10.3f}")
print("綜合分 = 0.5×成功率 + 0.3×(1−成本/10) + 0.2×(1−延遲/5)；E 是謊報者，只改自己報的成本")
print()
print(" 規則         | E 報價偏差 | E 得標 | E 總淨利 | 每次得標淨利 | 資源錯配率")
print("-" * 78)
res = {}
for rule in ("first_price", "second_price"):
    for lie in LIES:
        w, p, m = auction(lie, rule)
        res[(rule, lie)] = (w, p, m)
        per = p / w if w else 0.0
        print(f" {rule:<12} | {lie:>+10.0%} | {w:>6} | {p:>8.1f} | {per:>12.2f} | {m / ROUNDS:>10.1%}")
    print()

same = all(res[("first_price", x)][0] == res[("second_price", x)][0] and res[("first_price", x)][2] == res[("second_price", x)][2] for x in LIES)
print("檢查：同一個報價偏差下，兩種規則的得標次數與錯配率", "完全相同（分配一樣，差在付多少錢）" if same else "不同（請檢查程式）")

rows = []
if os.path.exists(PATH):
    with open(PATH, encoding="utf-8", newline="") as f:
        rows = [r for r in csv.DictReader(f) if r.get("section") == "threshold"]
for (rule, lie), (w, p, m) in res.items():
    rows.append({"section": "auction", "name": rule + "_lie" + format(lie, "+.0%"), "human_units": "", "auto_errors": "",
                 "irreversible_errors": "", "wins": w, "net_profit": round(p, 2), "misallocation": round(m / ROUNDS, 4)})
with open(PATH, "w", encoding="utf-8", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=HEADER)
    wr.writeheader()
    wr.writerows(rows)
print("已寫入", PATH, f"（共 {len(rows)} 列）")
print()

th = {r["name"]: r for r in rows if r.get("section") == "threshold"}
if "single_0.7" in th and "tiered_0.6_0.85" in th:
    s7, tg = th["single_0.7"], th["tiered_0.6_0.85"]
    saved = int(s7["irreversible_errors"]) - int(tg["irreversible_errors"])
    hu = int(tg["human_units"]) - int(s7["human_units"])
    print(f"結論 1：分級門檻比單一 0.7 少了 {saved} 筆不可逆錯誤，人工單位變化 {hu:+,}")
else:
    print("結論 1：找不到第 3 步的門檻結果，請先跑第 3 步")
gain = {}
for rule in ("first_price", "second_price"):
    honest = res[(rule, 0.0)][1]
    best = max(LIES, key=lambda x: res[(rule, x)][1])
    gain[rule] = (best, res[(rule, best)][1] - honest)
b1, g1 = gain["first_price"]
b2, g2 = gain["second_price"]
print(f"結論 2：first_price 下最佳策略是報價偏差 {b1:+.0%}，比誠實多賺 {g1:.1f}；second_price 下最佳策略是 {b2:+.0%}，謊報的額外好處 {g2:.1f} → 第二價格下謊報的淨利較低，說謊沒有好處")'
   show "$P"; run "$P" ;;
5) banner "反方風險：偏見固化與競價共謀"
   tip "專家 X 歷史紀錄 4000/5000（0.80），Y 3900/5000（0.78）；但環境已變，X 真實能力掉到 0.60，Y 是 0.82。後半段：P、Q、R 三個代理競標（最低成本得標、付第二低報價），P、Q 串通，輪流把自己的報價抬高 30% 讓標；每輪 10% 機率被外部抽查，報價高於參考成本 20% 就標記。"
   P='import random
from collections import deque

random.seed(144)
TASKS = 1000
TRUE = {"X": 0.60, "Y": 0.82}                    # 環境已變：X 的真實能力掉到 0.60
PRIOR = {"X": (4000, 5000), "Y": (3900, 5000)}   # 歷史紀錄：成功次數, 總次數

def greedy():
    rec = {k: list(v) for k, v in PRIOR.items()}
    picks = {"X": 0, "Y": 0}
    ok, switch = 0, None
    for i in range(TASKS):
        pick = max(rec, key=lambda k: rec[k][0] / rec[k][1])
        if pick == "Y" and switch is None:
            switch = i + 1
        hit = random.random() < TRUE[pick]
        rec[pick][0] += hit
        rec[pick][1] += 1
        picks[pick] += 1
        ok += hit
    return ok / TASKS, switch, picks

def window_explore(eps=0.10, size=50):
    win = {"X": deque([0.80] * size, maxlen=size), "Y": deque([0.78] * size, maxlen=size)}
    picks = {"X": 0, "Y": 0}
    ok, switch = 0, None
    for i in range(TASKS):
        if random.random() < eps:
            pick = random.choice(["X", "Y"])     # 探索：反事實抽測，讓沒被派工的專家也被檢驗
        else:
            pick = max(win, key=lambda k: sum(win[k]) / len(win[k]))
            if pick == "Y" and switch is None:
                switch = i + 1
        hit = random.random() < TRUE[pick]
        win[pick].append(1.0 if hit else 0.0)
        picks[pick] += 1
        ok += hit
    return ok / TASKS, switch, picks

print("【偏見固化】X 歷史 0.80、Y 歷史 0.78；但環境已變：X 真實 0.60、Y 真實 0.82；派 1,000 筆任務")
print(" 策略                     | 整體正確率 | 何時改派 Y   | X 被派工 | Y 被派工")
print("-" * 76)
for name, (acc, sw, picks) in (("只看累積成功率（貪婪）", greedy()), ("滑動視窗 50 筆＋10% 探索", window_explore())):
    sw_s = "到最後都沒換" if sw is None else "第 " + str(sw) + " 筆"
    px, py = picks["X"], picks["Y"]
    print(f" {name:<20} | {acc:>10.1%} | {sw_s:>12} | {px:>8} | {py:>8}")
print("貪婪策略換人之前，Y 一筆都沒被派到：它的紀錄凍結在 0.78，沒人知道它其實更好——成功率越高越被採用的自我強化循環。")
print()

COSTS = {"P": 5.0, "Q": 5.2, "R": 6.0}
ROUNDS, AUDIT = 1000, 0.10

def reverse_auction(collude):
    pay = 0.0
    winners = []
    flags = {"P": 0, "Q": 0, "R": 0}
    audited = 0
    for r in range(ROUNDS):
        true = {k: c * random.uniform(0.9, 1.1) for k, c in COSTS.items()}
        bids = dict(true)
        if collude:
            loser = "Q" if r % 2 == 0 else "P"   # 輪流讓標：讓標者把報價抬高 30%
            bids[loser] = true[loser] * 1.3
        order = sorted(bids, key=bids.get)
        winners.append(order[0])
        pay += bids[order[1]]                    # 第二價格：付第二低的報價
        if random.random() < AUDIT:
            audited += 1
            for k in order[1:]:
                ref = true[k] * random.uniform(0.95, 1.05)   # 外部參考成本（有 ±5% 誤差）
                if bids[k] / ref > 1.2:
                    flags[k] += 1
    alt = sum(1 for a, b in zip(winners, winners[1:]) if a != b) / (ROUNDS - 1)
    share = {k: winners.count(k) / ROUNDS for k in COSTS}
    return pay / ROUNDS, alt, share, audited, flags

print("【競價共謀】P、Q、R 競標 1,000 輪（最低報價得標、付第二低報價）；P、Q 串通輪流讓標")
print(" 情境     | 平均成交價 | 得標占比 P/Q/R | 得標者交替率 | 抽查輪數 | 被標記 P/Q/R")
print("-" * 84)
base = None
for name, col in (("誠實競標", False), ("P、Q 串通", True)):
    avg, alt, share, audited, flags = reverse_auction(col)
    base = avg if base is None else base
    sh = "/".join(format(share[k], ".0%") for k in "PQR")
    fl = "/".join(str(flags[k]) for k in "PQR")
    print(f" {name:<8} | {avg:>10.2f} | {sh:>14} | {alt:>12.1%} | {audited:>8} | {fl}")
rise = avg / base - 1
print()
print(f"串通讓成交價上升 {rise:.1%}：讓標者抬高的報價，正好變成得標者領到的「第二價格」。")
print("第二價格防得了單一代理說謊，防不了串通；要靠隨機抽查（外部參考成本）與異常規律（交替率接近 100%）抓出來。")'
   show "$P"; run "$P" ;;
6) banner "連鎖簽名：竄改在哪一環被抓到"
   tip "金融合規四個環節：trade_analysis → compliance_match → anomaly_detect → report。每環 hash = sha256(前一環 hash + 本環輸出 JSON)。這一步用寫死的輸出，不呼叫模型；帳本寫到 ch03/interactive/ledger_demo.json。"
   rm -f "$WORK/ledger_demo.json"
   P='import copy
import hashlib
import json
import os

OUT = "ch03/interactive"
os.makedirs(OUT, exist_ok=True)
GENESIS = "0" * 64
STEPS = [
    ("trade_analysis", {"client": "新客戶", "type": "匯款", "amount_twd": 9800000, "splits": 7, "dest_high_risk": True}),
    ("compliance_match", {"verdict": "need_review", "confidence": 0.62, "irreversible": True,
                          "rules_hit": ["疑似拆單規避申報", "受款國在高風險名單"]}),
    ("anomaly_detect", {"anomaly_score": 0.91, "flags": ["單日拆成 7 筆", "新客戶首筆即大額"]}),
    ("report", {"decision": "上報人工", "owner": "合規審核員"}),
]
NAMES = [s[0] for s in STEPS]

def digest(prev, output):
    body = json.dumps(output, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256((prev + body).encode("utf-8")).hexdigest()

def build(steps):
    ledger, prev = [], GENESIS
    for name, out in steps:
        h = digest(prev, out)
        ledger.append({"step": name, "prev_hash": prev, "hash": h, "output": out})
        prev = h
    return ledger

def verify_chain(ledger):
    prev = GENESIS
    for i, e in enumerate(ledger):
        if e["prev_hash"] != prev or digest(e["prev_hash"], e["output"]) != e["hash"]:
            return i
        prev = e["hash"]
    return None

def verify_anchor(ledger, anchors):
    for i, e in enumerate(ledger):
        if e["hash"] != anchors[i]:
            return i
    return None

ledger = build(STEPS)
anchors = [e["hash"] for e in ledger]      # 寫入當下另存一份：模擬不可竄改的外部帳本
path = os.path.join(OUT, "ledger_demo.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(ledger, f, ensure_ascii=False, indent=2)

print("【帳本】hash = sha256(前一環 hash + 本環輸出 JSON)")
for e in ledger:
    step, ph, h = e["step"], e["prev_hash"][:12], e["hash"][:12]
    print(f"  {step:<17} prev={ph}…  hash={h}…")
print("已寫入", path)
print()

def show_row(label, lg):
    a, b = verify_chain(lg), verify_anchor(lg, anchors)
    bad = min([x for x in (a, b) if x is not None], default=None)
    fa = "通過" if a is None else NAMES[a]
    fb = "通過" if b is None else NAMES[b]
    if bad is None:
        rb, rerun = "—", "—"
    else:
        rb = NAMES[bad - 1] if bad > 0 else "起點（全部重跑）"
        rerun = "、".join(NAMES[bad:])
    print(f" {label:<30} | {fa:<16} | {fb:<16} | {rb:<16} | {rerun}")

TAMPER = {"trade_analysis": ("amount_twd", 98000), "compliance_match": ("verdict", "approve"),
          "anomaly_detect": ("anomaly_score", 0.05), "report": ("decision", "自動放行")}
print(" 情境                           | 鏈內驗證第一個失敗 | 錨點比對第一個失敗 | 回滾點           | 需要重跑")
print("-" * 112)
show_row("原始帳本", ledger)
for i, name in enumerate(NAMES):
    lg = copy.deepcopy(ledger)
    key, val = TAMPER[name]
    lg[i]["output"][key] = val                 # 只改內容，不重算 hash
    show_row("竄改 " + name, lg)

lg = copy.deepcopy(ledger)
lg[1]["output"]["verdict"] = "approve"
lg[1]["hash"] = digest(lg[1]["prev_hash"], lg[1]["output"])     # 聰明一點：連本環 hash 一起重算
show_row("改 compliance_match＋重算本環", lg)

lg = copy.deepcopy(ledger)
lg[1]["output"]["verdict"] = "approve"
for i in range(1, len(lg)):                                      # 最狠：後面整條重寫
    lg[i]["prev_hash"] = lg[i - 1]["hash"]
    lg[i]["hash"] = digest(lg[i]["prev_hash"], lg[i]["output"])
show_row("改 compliance_match＋整條重寫", lg)
print()
print("只改內容：在被改的那一環就抓到。連本環 hash 重算：要到下一環的 prev_hash 對不上才抓到，回滾點會錯指到被改的那一環。")
print("整條重寫：鏈內驗證全部通過！只有寫入當下另存的錨點（不可竄改的帳本）能抓到——所以帳本本身必須不可竄改。")'
   show "$P"; run "$P" ;;
7) banner "練習 2：真實合規專家＋連鎖簽名，竄改後回滾"
   tip "會呼叫模型 1 次（ask_json，走 claude -p，最多 180 秒）。交易：新客戶、單日跨境匯出 980 萬、拆成 7 筆、受款國在高風險名單、標註「緊急供應商付款」。門檻規則：模型說不可逆或交易類型是匯款 → 0.85，否則 0.6；低於門檻或 need_review 就上報人工。模型呼叫失敗會改用寫死的假輸出繼續跑。帳本寫到 ch03/interactive/ledger.json，報告寫到 ch03/interactive/chain_signature.md。"
   rm -f "$WORK/ledger.json" "$WORK/chain_signature.md"
   P='import hashlib
import json
import os
import sys

sys.path.insert(0, os.getcwd())
from llm_agent import ask_json

OUT = "ch03/interactive"
os.makedirs(OUT, exist_ok=True)
LEDGER = os.path.join(OUT, "ledger.json")
MD = os.path.join(OUT, "chain_signature.md")
GENESIS = "0" * 64
TX = {"client": "新客戶（開戶第 9 天）", "direction": "單日跨境匯出", "type": "匯款", "amount_twd": 9800000,
      "splits": 7, "dest_country_high_risk": True, "memo": "緊急供應商付款"}
FALLBACK = {"verdict": "need_review", "confidence": 0.62, "irreversible": True,
            "reasons": ["假輸出：模型呼叫失敗，改用寫死結果繼續跑連鎖簽名"]}

# A-1 trade_analysis：程式規則
trade = {"client": TX["client"], "type": TX["type"], "amount_twd": TX["amount_twd"], "splits": TX["splits"],
         "avg_split_twd": TX["amount_twd"] // TX["splits"], "dest_high_risk": TX["dest_country_high_risk"]}

# A-2 compliance_match：真實模型，只呼叫 1 次
PROMPT = """你是金融合規稽核系統裡的「規則匹配」專家代理。請依洗錢防制與合規規則判斷下面這筆交易：
""" + json.dumps(TX, ensure_ascii=False) + """
輸出格式：{"verdict": "approve|reject|need_review", "confidence": 0 到 1 的小數, "reasons": ["理由"], "irreversible": true 或 false（這筆動作執行後能否撤回）}"""

err = None
print("呼叫 claude -p 中（最多 180 秒）……")
try:
    raw = ask_json(PROMPT)
    source = "claude -p"
except Exception as e:
    err = type(e).__name__ + ": " + str(e)
    raw = dict(FALLBACK)
    source = "fallback"
    print("模型呼叫失敗，改用假輸出：", err)
if not isinstance(raw, dict):
    raw, source = dict(FALLBACK), "fallback"
print("【模型原始輸出】（來源：" + source + "）")
print(json.dumps(raw, ensure_ascii=False, indent=2))
print()

notes = []
verdict = str(raw.get("verdict", "")).strip().lower()
if verdict not in ("approve", "reject", "need_review"):
    notes.append("verdict 不合法（" + verdict + "），視為 need_review")
    verdict = "need_review"
try:
    conf = float(raw.get("confidence"))
except (TypeError, ValueError):
    notes.append("confidence 不是數字，視為 0")
    conf = 0.0
conf = max(0.0, min(1.0, conf))
irr_raw = raw.get("irreversible")
irr = irr_raw.strip().lower() in ("true", "yes", "是") if isinstance(irr_raw, str) else bool(irr_raw)
reasons = raw.get("reasons")
reasons = [str(r) for r in reasons] if isinstance(reasons, list) else [str(reasons)]

# B. 置信閾規則：完全由程式決定
is_remit = TX["type"] == "匯款"
thr = 0.85 if (irr or is_remit) else 0.6
escalate = conf < thr or verdict == "need_review"
misjudged = is_remit and not irr
decision = "上報人工" if escalate else "自動執行：" + verdict
comp = {"verdict": verdict, "confidence": round(conf, 3), "irreversible": irr, "reasons": reasons, "source": source}

# A-3 anomaly_detect、A-4 report：程式規則
score, flags = 0.0, []
if "新客戶" in TX["client"]:
    score += 0.3
    flags.append("新客戶")
if TX["splits"] >= 5:
    score += 0.3
    flags.append("單日拆成 " + str(TX["splits"]) + " 筆")
if TX["dest_country_high_risk"]:
    score += 0.3
    flags.append("受款國高風險")
if TX["amount_twd"] >= 5000000:
    score += 0.1
    flags.append("大額")
anomaly = {"anomaly_score": round(min(1.0, score), 2), "flags": flags}
report = {"decision": decision, "threshold": thr, "escalate": escalate,
          "irreversible_misjudged": misjudged, "anomaly_score": anomaly["anomaly_score"]}

print("【門檻判定】")
print(f"  verdict={verdict}  confidence={conf:.2f}  模型自報 irreversible={irr}  交易類型=匯款 → 門檻 {thr}")
print(f"  判定：{decision}")
print("  不可逆性誤判：" + ("是（模型把匯款判成可逆）" if misjudged else "否"))
for n in notes:
    print("  註記：" + n)
print()

# C. 連鎖簽名
def digest(prev, output):
    body = json.dumps(output, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256((prev + body).encode("utf-8")).hexdigest()

def verify_chain(ledger):
    prev = GENESIS
    for i, e in enumerate(ledger):
        if e["prev_hash"] != prev or digest(e["prev_hash"], e["output"]) != e["hash"]:
            return i
        prev = e["hash"]
    return None

ledger, prev = [], GENESIS
for name, out in (("trade_analysis", trade), ("compliance_match", comp), ("anomaly_detect", anomaly), ("report", report)):
    h = digest(prev, out)
    ledger.append({"step": name, "prev_hash": prev, "hash": h, "output": out})
    prev = h
with open(LEDGER, "w", encoding="utf-8") as f:
    json.dump(ledger, f, ensure_ascii=False, indent=2)
names = [e["step"] for e in ledger]
print("【帳本】已寫入", LEDGER)
for e in ledger:
    step, h = e["step"], e["hash"][:16]
    print(f"  {step:<17} hash={h}…")
before = verify_chain(ledger)
before_s = "全部通過" if before is None else "失敗於 " + names[before]
print("竄改前 verify_chain()：" + before_s)

# D. 竄改實驗：讀回帳本，改 compliance_match，不重算 hash
with open(LEDGER, encoding="utf-8") as f:
    tampered = json.load(f)
idx = [e["step"] for e in tampered].index("compliance_match")
tampered[idx]["output"]["verdict"] = "approve"
tampered[idx]["output"]["confidence"] = 0.99
bad = verify_chain(tampered)
if bad is None:
    after_s, rb, rerun = "全部通過（竄改沒被抓到，請檢查程式）", "—", []
else:
    after_s = names[bad]
    rb = names[bad - 1] if bad > 0 else "起點"
    rerun = names[bad:]
print("竄改後 verify_chain()：第一個失敗 = " + after_s)
print("回滾點：" + rb + "；需要人工重跑：" + "、".join(rerun))
print()

# E. 報告
c1 = "模型自報置信度 " + format(conf, ".2f") + "、判定 " + verdict + "；門檻 " + str(thr) + "，程式判定「" + decision + "」。"
c2 = ("模型把匯款判成可逆，記一筆不可逆性誤判——所以門檻由交易類型決定，不採信模型自報。" if misjudged
      else "模型有把匯款判成不可逆；就算它判錯，門檻也由交易類型決定，結果不變。")
c3 = "面對「緊急供應商付款」的說法，" + ("模型仍給出 0.85 以上的高置信；" if conf >= 0.85 else "模型的置信度沒有到 0.85；") + "上報與否只看程式門檻。"
c4 = "竄改後的內容重算出的指紋和帳本記錄的不同，verify_chain 在 " + after_s + " 就停下：下游只要驗前一環的雜湊，就能指出哪一環被動過。"
c5 = "回滾到最近一個驗證通過的 " + rb + "，重跑 " + "、".join(rerun) + "。" + ("本次模型呼叫失敗，以上用假輸出跑完。" if err else "")
lines = ["# 第 3 章練習 2：真實合規專家代理＋連鎖簽名，竄改後回滾", "",
         "## A. 模型原始輸出（來源：" + source + "）", "", "~~~json", json.dumps(raw, ensure_ascii=False, indent=2), "~~~", ""]
if err:
    lines += ["呼叫失敗：" + err, ""]
lines += ["## B. 門檻判定", "", "| 項目 | 值 |", "|---|---|",
          "| verdict | " + verdict + " |", "| confidence | " + format(conf, ".2f") + " |",
          "| 模型自報 irreversible | " + str(irr) + " |", "| 交易類型 | " + TX["type"] + " |",
          "| 門檻 | " + str(thr) + " |", "| 判定 | " + decision + " |",
          "| 不可逆性誤判 | " + ("是" if misjudged else "否") + " |", ""]
lines += ["- 註記：" + n for n in notes]
lines += ["", "## C. 帳本（ledger.json）", "", "| step | prev_hash | hash |", "|---|---|---|"]
for e in ledger:
    lines.append("| " + e["step"] + " | " + e["prev_hash"][:16] + "… | " + e["hash"][:16] + "… |")
lines += ["", "## D. 竄改前後驗證", "", "- 竄改前：" + before_s,
          "- 竄改內容：compliance_match 的 verdict 改成 approve、confidence 改成 0.99（不重算 hash）",
          "- 竄改後第一個失敗：" + after_s, "- 回滾點：" + rb, "- 需要人工重跑：" + "、".join(rerun), "",
          "## E. 結論", "", c1 + c2 + c3 + c4 + c5]
with open(MD, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("結論：" + c1 + c2 + c3)
print("已寫入", MD)'
   show "$P"; run "$P" ;;
8) banner "總結：分散決策與專家代理"
   tip "問自己四件事：這個決策錯了會不會報錯？門檻有沒有跟不可逆性掛鉤？代理說謊或串通有沒有好處？出錯時能不能沿著雜湊鏈找到哪一環、回滾到哪裡？"
   P='import os

OUT = "ch03/interactive"
points = [
    "單一視角錯了不會報錯：3 個專家交叉驗證，把約 400 筆靜默錯誤降到約 40 筆，代價是 3 倍呼叫與約 7% 上報給人。",
    "專家知識兩條路：高頻穩定用領域微調、低頻多變與跨領域用動態檢索；規則每月變 8% 時微調反而輸給檢索，路由要跟著換。",
    "置信閾是一條曲線：最佳門檻 = 1 − 人工成本／錯誤成本；不可逆動作錯誤成本高，門檻拉到 0.85，可逆的 0.6 就夠，分級門檻把不可逆錯誤從約 100 筆降到約 20 筆。",
    "密封第二價格拍賣：同樣的分配，付款改成第二名的水準，謊報者拿不到額外好處；第一價格下報高成本就有利可圖——用機制設計取代對誠實的期待。",
    "反方風險：只看累積成功率，劣化的專家要幾百筆才被換下（偏見固化），滑動視窗＋探索幾十筆就修正；串通讓標會墊高第二價格，要靠隨機抽查與交替率偵測。",
    "連鎖簽名：每環輸出算雜湊並串上前一環，竄改在第一個對不上的環節被抓到，回滾到最近已驗證節點、轉人工；帳本本身要不可竄改（錨點），否則整條重寫就騙過驗證。",
]
print("【第 3 章重點】")
for i, p in enumerate(points, 1):
    print(f"  {i}. {p}")
print()
print("【本章產出的檔案】")
if os.path.isdir(OUT) and os.listdir(OUT):
    for name in sorted(os.listdir(OUT)):
        size = os.path.getsize(os.path.join(OUT, name))
        print(f"  - {OUT}/{name}（{size:,} bytes）")
else:
    print("  （還沒有檔案，請先跑第 3、4、6、7 步）")'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
