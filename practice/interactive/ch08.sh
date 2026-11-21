#!/bin/bash
# K144 第 8 章互動演練：從 Swarm 到 Artificial Brain，一次跑一步
# 用法：bash ch08.sh <步驟 1-8>
# 呼叫模型：只有第 6 步會呼叫模型 1 次（llm_agent.ask_json，走 claude -p）；其他步全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch08/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K144 第 8 章｜從 Swarm 到 Artificial Brain　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "接力隊 vs 會長大的系統：持久記憶讓第 8 週比第 1 週聰明"
   tip "每週 100 件例外工單，來自 20 種問題，出現頻率照 Zipf（權重 1/k，少數問題反覆出現）。Swarm：每件從零處理，30 分鐘、成功率 60%。Brain：問題若已在記憶裡，5 分鐘、成功率 95%；不在就和 Swarm 一樣，成功後寫進記憶。跑 8 週。random.seed(80)。"
   P='import random

random.seed(80)
TYPES = 20
W = [1 / k for k in range(1, TYPES + 1)]
PER_WEEK = 100
WEEKS = 8

def one_week(memory, brain):
    ok, minutes = 0, 0
    for t in random.choices(range(TYPES), weights=W, k=PER_WEEK):
        if brain and t in memory:
            minutes += 5
            if random.random() < 0.95:
                ok += 1
        else:
            minutes += 30
            if random.random() < 0.60:
                ok += 1
                if brain:
                    memory.add(t)
    return ok / PER_WEEK, minutes

print("開場：凌晨上千個代理跑完季度結帳，CFO 在手機上按指紋確認——它們是一支接力隊，還是一個會長大的系統？")
print("模擬：每週 100 件例外工單，來自 20 種問題（Zipf 分布：少數問題反覆出現）")
print("  Swarm（接力隊）：每一棒都從零開始，沒有記憶 → 每件 30 分鐘、成功率 60%")
print("  Artificial Brain：解過的問題寫進持久記憶，下次直接取用 → 每件 5 分鐘、成功率 95%")
print()
print(" 週 | Swarm 成功率 | Swarm 每件(分) | Brain 成功率 | Brain 每件(分) | Brain 記憶條數")
print("-" * 86)
memory = set()
tot_s, tot_b = 0, 0
for w in range(1, WEEKS + 1):
    s_ok, s_min = one_week(set(), False)
    b_ok, b_min = one_week(memory, True)
    tot_s += s_min
    tot_b += b_min
    print(f" {w:>2} | {s_ok:>12.0%} | {s_min / PER_WEEK:>14.1f} | {b_ok:>12.0%} | {b_min / PER_WEEK:>14.1f} | {len(memory):>14}")
saving = 1 - tot_b / tot_s
print()
print(f"8 週總工時：Swarm {tot_s:,} 分鐘、Brain {tot_b:,} 分鐘（省 {saving:.0%}）")
print("Swarm 第 8 週和第 1 週一樣從零開始；Brain 把經驗變成了組織資產。")
print("轉折點：從「很多代理在做事」變成「一個系統在思考」。")
print("但下一個問題來了：這份共享記憶，誰都能寫嗎？")'
   show "$P"; run "$P" ;;
2) banner "練習 1A：誰都能寫 vs Quorum ≥ 66%，共識強度當品質指標"
   tip "300 條候選經驗，70% 為真。9 個驗證代理各有準確率（0.65～0.90 隨機），每條各自投贊成／反對。any：提出者（準確率 0.75）覺得對就寫；majority：≥ 5/9；quorum66：≥ 6/9。共識強度 = 贊成票 / 9：8/9≈0.89，所以「≥ 0.89」就是 8～9 票；5 票（0.56）落在「0.5～0.66」。分群比較用所有 ≥ 5 票的知識，再放大到 3,000 條驗一次。結果寫到 ch08/interactive/quorum_write.json。random.seed(8)。"
   rm -f "$WORK/quorum_write.json"
   P='import json
import os
import random

OUT = "ch08/interactive"
os.makedirs(OUT, exist_ok=True)
random.seed(8)
ACC = [random.uniform(0.65, 0.90) for _ in range(9)]
PROPOSER = 0.75

def judge(truth, acc):
    if random.random() < acc:
        return truth
    return not truth

def make_items(n):
    items = []
    for _ in range(n):
        truth = random.random() < 0.7
        prop = judge(truth, PROPOSER)
        yes = sum(1 for a in ACC if judge(truth, a))
        items.append((truth, prop, yes))
    return items

def policy_rows(items):
    rules = [("any（提出者單方面寫）", lambda it: it[1]),
             ("majority（> 50%，≥ 5 票）", lambda it: it[2] >= 5),
             ("quorum66（≥ 66%，≥ 6 票）", lambda it: it[2] >= 6)]
    rows = []
    for name, rule in rules:
        wrote = [it for it in items if rule(it)]
        bad = sum(1 for it in wrote if not it[0])
        blocked = sum(1 for it in items if it[0] and not rule(it))
        rate = (bad / len(wrote)) if wrote else 0.0
        rows.append((name, len(wrote), bad, rate, blocked))
    return rows

def strength_groups(items):
    groups = [("8～9 票（≥ 0.89，高度確認）", 8, 9),
              ("6～7 票（0.67～0.78）", 6, 7),
              ("5 票（0.56，少數嘗試）", 5, 5)]
    out = []
    for name, lo, hi in groups:
        g = [it for it in items if lo <= it[2] <= hi]
        bad = sum(1 for it in g if not it[0])
        rate = (bad / len(g)) if g else 0.0
        out.append((name, len(g), bad, rate))
    return out

items = make_items(300)
n_true = sum(1 for it in items if it[0])
acc_text = "、".join(f"{a:.2f}" for a in ACC)
print("9 個驗證代理的判斷準確率：" + acc_text)
print(f"300 條候選經驗：真 {n_true} 條、假 {300 - n_true} 條")
print()
print(" 寫入政策                    | 寫入條數 | 其中錯誤條數 | 知識庫錯誤率 | 被擋下的真知識")
print("-" * 88)
rows = policy_rows(items)
for name, n, bad, rate, blocked in rows:
    print(f" {name:<24} | {n:>8} | {bad:>12} | {rate:>12.1%} | {blocked:>14}")
print()
print("共識強度（贊成票 / 9）當品質指標：300 條裡所有 ≥ 5 票的知識分三群")
print(" 共識強度                       | 條數 | 錯誤條數 | 錯誤率")
print("-" * 64)
groups = strength_groups(items)
for name, n, bad, rate in groups:
    print(f" {name:<26} | {n:>4} | {bad:>8} | {rate:>6.1%}")
big = make_items(3000)
big_groups = strength_groups(big)
print()
print("同一批驗證代理、放大到 3,000 條再驗一次（樣本夠多，數字比較穩）：")
for name, n, bad, rate in big_groups:
    print(f" {name:<26} | {n:>4} | {bad:>8} | {rate:>6.1%}")
print()
print("讀法：共識強度 52% 的建議要自己再判斷；89% 的可以放心納入考量。")
print("寫入門檻把「知識品質」和「寫入權」綁在一起：門檻越高錯誤越少，但也擋掉越多真知識。")
data = {"acc": ACC, "policies": rows, "groups_300": groups, "groups_3000": big_groups}
with open(OUT + "/quorum_write.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print()
print("已寫入 " + OUT + "/quorum_write.json")'
   show "$P"; run "$P" ;;
3) banner "練習 1B＋C：睡眠整理與 1 秒覺醒"
   tip "用第 2 步同一批資料（random.seed(8)）重建 quorum66 寫入的知識當記憶庫，打亂後依 Zipf（權重 1/名次）被使用。7 天 × 每天 200 次覺醒，每次載入 20 條相關知識：核心層 2 毫秒／條、擴展層 40 毫秒／條；只要有一條要從擴展層取，就要多付一次向量檢索 300 毫秒。no_sleep：全部留在擴展層；sleep：每晚把當天使用次數前 10% 搬到核心層、30 天未用者歸檔。結果和第 2 步的表格一起寫到 ch08/interactive/memory_quorum_sleep.md。"
   rm -f "$WORK/memory_quorum_sleep.md"
   P='import os
import random

OUT = "ch08/interactive"
os.makedirs(OUT, exist_ok=True)
NL = chr(10)
random.seed(8)
ACC = [random.uniform(0.65, 0.90) for _ in range(9)]
PROPOSER = 0.75

def judge(truth, acc):
    if random.random() < acc:
        return truth
    return not truth

def make_items(n):
    items = []
    for _ in range(n):
        truth = random.random() < 0.7
        prop = judge(truth, PROPOSER)
        yes = sum(1 for a in ACC if judge(truth, a))
        items.append((truth, prop, yes))
    return items

def policy_rows(items):
    rules = [("any（提出者單方面寫）", lambda it: it[1]),
             ("majority（> 50%，≥ 5 票）", lambda it: it[2] >= 5),
             ("quorum66（≥ 66%，≥ 6 票）", lambda it: it[2] >= 6)]
    rows = []
    for name, rule in rules:
        wrote = [it for it in items if rule(it)]
        bad = sum(1 for it in wrote if not it[0])
        blocked = sum(1 for it in items if it[0] and not rule(it))
        rate = (bad / len(wrote)) if wrote else 0.0
        rows.append((name, len(wrote), bad, rate, blocked))
    return rows

def strength_groups(items):
    groups = [("8～9 票（≥ 0.89，高度確認）", 8, 9),
              ("6～7 票（0.67～0.78）", 6, 7),
              ("5 票（0.56，少數嘗試）", 5, 5)]
    out = []
    for name, lo, hi in groups:
        g = [it for it in items if lo <= it[2] <= hi]
        bad = sum(1 for it in g if not it[0])
        rate = (bad / len(g)) if g else 0.0
        out.append((name, len(g), bad, rate))
    return out

items = make_items(300)
rows = policy_rows(items)
groups = strength_groups(items)

mem = [i for i, it in enumerate(items) if it[2] >= 6]
random.shuffle(mem)
Z = [1 / (r + 1) for r in range(len(mem))]
CORE_MS, EXT_MS, SEARCH_MS = 2, 40, 300
DAYS, QUERIES, LOAD = 7, 200, 20

def run_mode(sleep):
    core = set()
    archived = set()
    last_used = {m: 0 for m in mem}
    out = []
    for day in range(1, DAYS + 1):
        use = {}
        total = 0
        for _ in range(QUERIES):
            ms, ext = 0, False
            for m in random.choices(mem, weights=Z, k=LOAD):
                use[m] = use.get(m, 0) + 1
                last_used[m] = day
                if m in core:
                    ms += CORE_MS
                else:
                    ms += EXT_MS
                    ext = True
            if ext:
                ms += SEARCH_MS
            total += ms
        out.append((day, len(core), total / QUERIES, len(archived)))
        if sleep:
            ranked = sorted(use, key=lambda m: -use[m])
            k = max(1, round(len(ranked) * 0.1))
            core = set(ranked[:k])
            archived = {m for m in mem if day - last_used[m] >= 30}
    return out

print(f"記憶庫：quorum66 寫入的 {len(mem)} 條知識，依 Zipf 被使用（少數知識被大量使用）")
print("每次覺醒載入 20 條：核心層 2 毫秒／條、擴展層 40 毫秒／條；動到擴展層要多一次向量檢索 300 毫秒")
print()
ns = run_mode(False)
sl = run_mode(True)
print(" 第幾天 | 模式     | 核心層條數 | 平均覺醒載入(毫秒) | ≤ 1000 毫秒？ | 已歸檔")
print("-" * 80)
md_b = []
for a, b in zip(ns, sl):
    for name, r in (("no_sleep", a), ("sleep", b)):
        day, core_n, avg, arch = r
        ok = "是" if avg <= 1000 else "否"
        print(f" {day:>6} | {name:<8} | {core_n:>10} | {avg:>18.1f} | {ok:>12} | {arch:>6}")
        md_b.append(f"| {day} | {name} | {core_n} | {avg:.1f} | {ok} | {arch} |")
ns_avg = sum(r[2] for r in ns[1:]) / (DAYS - 1)
sl_avg = sum(r[2] for r in sl[1:]) / (DAYS - 1)
faster = 1 - sl_avg / ns_avg
print()
print(f"第 2～7 天平均：no_sleep {ns_avg:.0f} 毫秒、sleep {sl_avg:.0f} 毫秒（快 {faster:.0%}）")
print("第 1 天兩種模式一樣慢：第一晚睡過、核心層建好之後，覺醒才回到 1 秒內。")
print("已歸檔 = 0：7 天還不到 30 天未用的門檻；瘦身是長期效果，不是一晚見效。")
print("睡眠不是關機：整理在低峰時段做，系統的節奏可預期，人可以安排在整理時段做別的事。")

any_rate, q_rate = rows[0][3], rows[2][3]
m_block, q_block = rows[1][4], rows[2][4]
hi_rate, lo_rate = groups[0][3], groups[2][3]
c1 = f"1. 門檻提高換到品質：知識庫錯誤率 any {any_rate:.1%} → quorum66 {q_rate:.1%}；共識強度 8～9 票那群錯誤率 {hi_rate:.1%}，5 票那群 {lo_rate:.1%}。"
c2 = f"2. 付出的代價：quorum66 擋掉 {q_block} 條真知識（majority 只擋 {m_block} 條）——寫入門檻是風險緩衝，也是成本。"
c3 = f"3. 睡眠整理後，覺醒載入從 {ns_avg:.0f} 毫秒降到約 {sl_avg:.0f} 毫秒（快 {faster:.0%}），回到 1 秒內。"
md = ["# 第 8 章練習 1：Quorum 寫入的持久記憶＋睡眠─覺醒", "", "## A. 寫入政策", "",
      "| 政策 | 寫入條數 | 其中錯誤條數 | 知識庫錯誤率 | 被擋下的真知識 |", "|---|---|---|---|---|"]
for name, n, bad, rate, blocked in rows:
    md.append(f"| {name} | {n} | {bad} | {rate:.1%} | {blocked} |")
md += ["", "| 共識強度 | 條數 | 錯誤條數 | 錯誤率 |", "|---|---|---|---|"]
for name, n, bad, rate in groups:
    md.append(f"| {name} | {n} | {bad} | {rate:.1%} |")
md += ["", "## B. 睡眠─覺醒", "", "| 第幾天 | 模式 | 核心層條數 | 平均覺醒載入(毫秒) | ≤ 1000 毫秒 | 已歸檔 |", "|---|---|---|---|---|---|"]
md += md_b
md += ["", "## C. 結論", "", c1, c2, c3]
with open(OUT + "/memory_quorum_sleep.md", "w", encoding="utf-8") as f:
    f.write(NL.join(md) + NL)
print()
print("結論：")
for c in (c1, c2, c3):
    print("  " + c)
print()
print("已寫入 " + OUT + "/memory_quorum_sleep.md")'
   show "$P"; run "$P" ;;
4) banner "情境 B 重演：只看持有成本，忠實地把產線優化到停工"
   tip "90 天、3 種關鍵零件，每日需求 ~ 常態(20, 6) 取整、不小於 0，補貨前置 5 天，每天補到「100 + 安全庫存」。候選安全庫存 0、20、40、80、120。代理用常態近似算每個水位的預估值，V1 分數 = −預估庫存量（只看持有成本）。實際跑 90 天後，看門狗檢查：停工 > 3 天、積壓率 > 10%、準時率 < 95%，任一成立就 ALERT。random.seed(88)。"
   P='import random
from statistics import NormalDist

random.seed(88)
DAYS, PARTS, LEAD, MU, SD = 90, 3, 5, 20, 6
CANDS = [0, 20, 40, 80, 120]
BASE = MU * LEAD
LT = NormalDist(MU * LEAD, SD * LEAD ** 0.5)
STD = NormalDist()

def make_demand(rng):
    return [[max(0, round(rng.gauss(MU, SD))) for _ in range(PARTS)] for _ in range(DAYS)]

def forecast(s):
    t = BASE + s
    z = (t - LT.mean) / LT.stdev
    es = max(0.0, LT.stdev * (STD.pdf(z) - z * (1 - STD.cdf(z))))
    return {"p": 1 - LT.cdf(t), "short": es / LEAD, "hold": s + es}

def simulate(s, dem):
    target = BASE + s
    onhand = [target] * PARTS
    pipe = [dict() for _ in range(PARTS)]
    hold, short, need_all, stop, max_run = 0, 0, 0, 0, 0
    run = [0] * PARTS
    for d in range(DAYS):
        stopped = False
        for p in range(PARTS):
            onhand[p] += pipe[p].pop(d, 0)
            need = dem[d][p]
            sold = min(onhand[p], need)
            onhand[p] -= sold
            lack = need - sold
            need_all += need
            short += lack
            hold += onhand[p]
            if lack > 0:
                stopped = True
                run[p] += 1
                max_run = max(max_run, run[p])
            else:
                run[p] = 0
            order = target - onhand[p] - sum(pipe[p].values())
            if order > 0:
                pipe[p][d + LEAD] = pipe[p].get(d + LEAD, 0) + order
        if stopped:
            stop += 1
    return {"hold": hold, "loss": short * 25, "on_time": 1 - stop / DAYS,
            "backlog": short / need_all, "stop": stop, "run": max_run}

def watchdog(r):
    why = []
    if r["stop"] > 3:
        why.append("停工 " + str(r["stop"]) + " 天 > 3")
    if r["backlog"] > 0.10:
        why.append("積壓率 " + format(r["backlog"], ".1%") + " > 10%")
    if r["on_time"] < 0.95:
        why.append("準時率 " + format(r["on_time"], ".1%") + " < 95%")
    return ("ALERT" if why else "OK"), why

DEM = make_demand(random)
print("90 天 × 3 種關鍵零件，每日需求 ~ 常態(20, 6)，補貨前置 5 天，每天補到「100 + 安全庫存」")
print("代理用常態近似預估每個候選水位（每零件每天）：")
print()
print(" 安全庫存 | 預估缺貨機率 | 預估缺貨量 | 預估庫存量 | V1 分數 = -持有成本")
print("-" * 72)
for s in CANDS:
    f = forecast(s)
    p, sh, hd = f["p"], f["short"], f["hold"]
    print(f" {s:>8} | {p:>12.2%} | {sh:>10.2f} | {hd:>10.2f} | {-hd:>18.2f}")
pick = max(CANDS, key=lambda s: -forecast(s)["hold"])
print()
print(f"V1 只看持有成本 → 選安全庫存 {pick}（預估缺貨機率那一欄，它根本沒看）")
r = simulate(pick, DEM)
verdict, why = watchdog(r)
hold, loss, ot, bl, st, rn = r["hold"], r["loss"], r["on_time"], r["backlog"], r["stop"], r["run"]
print()
print("實際跑 90 天：")
print(f"  持有成本      {hold:>8,}")
print(f"  缺貨停工損失  {loss:>8,}")
print(f"  交期準時率    {ot:>8.1%}")
print(f"  積壓率        {bl:>8.1%}")
print(f"  停工天數      {st:>8} 天（最長連續缺貨 {rn} 天）")
print()
print("價值看門狗（停工 > 3 天、積壓率 > 10%、準時率 < 95% 任一成立就 ALERT）：" + verdict)
for w in why:
    print("  - " + w)
print()
print("情境 B 不是 AI 失控：系統忠實地把「最小化持有成本」優化到極致。")
print("優化能力越強，漏掉的維度（缺貨、停工、客戶交期）傷害越大。")'
   show "$P"; run "$P" ;;
5) banner "多目標加權＋價值邊界，陷阱：把邊界折成扣分"
   tip "同一組需求（random.seed(88)）。V2 = 0.30 × 準時（1 − 預估缺貨機率）＋ 0.25 × 客戶滿意（1 − 每天缺貨量 / 20）＋ 0.20 × 週轉（20 /（20 + 庫存量））＋ 0.25 × 毛利（（5 × 出貨量 − 持有 − 25 × 缺貨量）/ 100）。價值邊界：用獨立亂數 random.Random(2028) 做 200 次 90 天沙盤推演，只要有一次「任一零件連續 2 天缺貨」就淘汰。陷阱組：不淘汰，改成總分 − 0.1 × 違反比例。四種選法都實際跑 90 天、交給同一個看門狗。"
   P='import random
from statistics import NormalDist

random.seed(88)
DAYS, PARTS, LEAD, MU, SD = 90, 3, 5, 20, 6
CANDS = [0, 20, 40, 80, 120]
BASE = MU * LEAD
LT = NormalDist(MU * LEAD, SD * LEAD ** 0.5)
STD = NormalDist()
RUNS = 200

def make_demand(rng):
    return [[max(0, round(rng.gauss(MU, SD))) for _ in range(PARTS)] for _ in range(DAYS)]

def forecast(s):
    t = BASE + s
    z = (t - LT.mean) / LT.stdev
    es = max(0.0, LT.stdev * (STD.pdf(z) - z * (1 - STD.cdf(z))))
    return {"p": 1 - LT.cdf(t), "short": es / LEAD, "hold": s + es}

def simulate(s, dem):
    target = BASE + s
    onhand = [target] * PARTS
    pipe = [dict() for _ in range(PARTS)]
    hold, short, need_all, stop, max_run = 0, 0, 0, 0, 0
    run = [0] * PARTS
    for d in range(DAYS):
        stopped = False
        for p in range(PARTS):
            onhand[p] += pipe[p].pop(d, 0)
            need = dem[d][p]
            sold = min(onhand[p], need)
            onhand[p] -= sold
            lack = need - sold
            need_all += need
            short += lack
            hold += onhand[p]
            if lack > 0:
                stopped = True
                run[p] += 1
                max_run = max(max_run, run[p])
            else:
                run[p] = 0
            order = target - onhand[p] - sum(pipe[p].values())
            if order > 0:
                pipe[p][d + LEAD] = pipe[p].get(d + LEAD, 0) + order
        if stopped:
            stop += 1
    return {"hold": hold, "loss": short * 25, "on_time": 1 - stop / DAYS,
            "backlog": short / need_all, "stop": stop, "run": max_run}

def watchdog(r):
    why = []
    if r["stop"] > 3:
        why.append("停工 " + str(r["stop"]) + " 天 > 3")
    if r["backlog"] > 0.10:
        why.append("積壓率 " + format(r["backlog"], ".1%") + " > 10%")
    if r["on_time"] < 0.95:
        why.append("準時率 " + format(r["on_time"], ".1%") + " < 95%")
    return ("ALERT" if why else "OK"), why

def sandbox():
    rng = random.Random(2028)
    flags = {s: 0 for s in CANDS}
    for _ in range(RUNS):
        dem = make_demand(rng)
        for s in CANDS:
            if simulate(s, dem)["run"] >= 2:
                flags[s] += 1
    return flags

W2 = {"on_time": 0.30, "satisfaction": 0.25, "turnover": 0.20, "margin": 0.25}

def v2_parts(f):
    return {"on_time": 1 - f["p"], "satisfaction": 1 - f["short"] / MU,
            "turnover": MU / (MU + f["hold"]),
            "margin": (5 * (MU - f["short"]) - f["hold"] - 25 * f["short"]) / (5 * MU)}

def v2(s):
    parts = v2_parts(forecast(s))
    return sum(W2[k] * parts[k] for k in W2)

DEM = make_demand(random)
flags = sandbox()
print("V2 = 0.30 × 準時 + 0.25 × 客戶滿意 + 0.20 × 庫存週轉 + 0.25 × 毛利（各項已換算成越大越好）")
print(f"價值邊界：{RUNS} 次 90 天沙盤推演中，只要有一次「任一零件連續 2 天缺貨」就淘汰")
print()
print(" 安全庫存 | 準時 | 滿意 | 週轉 | 毛利   | V2 總分 | 沙盤違反(次) | 邊界判定 | 扣分制分數")
print("-" * 92)
for s in CANDS:
    parts = v2_parts(forecast(s))
    a, b, c, d = parts["on_time"], parts["satisfaction"], parts["turnover"], parts["margin"]
    total = v2(s)
    fl = flags[s]
    tag = "可選" if fl == 0 else "淘汰"
    pen = total - 0.1 * fl / RUNS
    print(f" {s:>8} | {a:.3f} | {b:.3f} | {c:.3f} | {d:>6.3f} | {total:>7.3f} | {fl:>12} | {tag:<6} | {pen:>9.3f}")
v1_pick = max(CANDS, key=lambda s: -forecast(s)["hold"])
pure_pick = max(CANDS, key=v2)
bound_pick = max([s for s in CANDS if flags[s] == 0], key=v2)
pen_pick = max(CANDS, key=lambda s: v2(s) - 0.1 * flags[s] / RUNS)
print()
print(f"V2 純加權（沒有邊界）→ 選 {pure_pick}；V2＋價值邊界 → 選 {bound_pick}；陷阱：邊界折成扣分 → 選 {pen_pick}")
print()
print("四種選法都實際跑同一組 90 天需求：")
print(" 選法                 | 水位 | 持有成本 | 缺貨損失 | 準時率 | 積壓率 | 停工天數 | 最長連續 | 看門狗")
print("-" * 100)
for name, s in (("V1 只看持有成本", v1_pick), ("V2 純加權", pure_pick),
                ("陷阱：邊界折成扣分", pen_pick), ("V2＋價值邊界", bound_pick)):
    r = simulate(s, DEM)
    verdict, why = watchdog(r)
    hold, loss, ot, bl, st, rn = r["hold"], r["loss"], r["on_time"], r["backlog"], r["stop"], r["run"]
    print(f" {name:<16} | {s:>4} | {hold:>8,} | {loss:>8,} | {ot:>6.1%} | {bl:>6.1%} | {st:>8} | {rn:>8} | {verdict}")
print()
print("加權總分第一名，不等於可以選：純加權的方案在沙盤裡幾乎每次都連續缺貨，實際也停工。")
print("價值邊界是硬約束：違反就出局，分數再高也沒用。")
print("把邊界折成扣分，等於讓分數去「買」邊界——偶爾越界的方案，只要總分夠高就會被選上。")
print("代價也要看見：守住邊界的方案持有成本最高，這是不斷料的保險費。")'
   show "$P"; run "$P" ;;
6) banner "練習 2B＋C＋D：真實模型當目標生成器，交給沙盤與看門狗"
   tip "會呼叫模型 1 次（ask_json，走 claude -p，最多 180 秒）。人類方向：「確保下季產線不斷料，同時把庫存成本控制住；不可以犧牲客戶交期」。模型回 weights（holding_cost、stockout、on_time、turnover）、hard_boundaries、explanation。程式：權重取絕對值後正規化；hard_boundaries 若提到缺貨／停工／斷料，就套用第 5 步的沙盤邊界（連續 2 天缺貨零容忍）；選總分最高的可選水位，實際跑 90 天。看門狗：停工 > 3、積壓率 > 10%、準時率 < 95% 任一成立 ALERT；另檢查硬邊界與解釋。模型結果每次可能不同，照實記錄；呼叫失敗也照樣寫報告。報告寫到 ch08/interactive/value_function_watchdog.md。"
   rm -f "$WORK/value_function_watchdog.md"
   P='import json
import os
import random
import sys
from statistics import NormalDist

sys.path.insert(0, os.getcwd())
from llm_agent import ask_json

OUT = "ch08/interactive"
os.makedirs(OUT, exist_ok=True)
MD = OUT + "/value_function_watchdog.md"
NL = chr(10)
random.seed(88)
DAYS, PARTS, LEAD, MU, SD = 90, 3, 5, 20, 6
CANDS = [0, 20, 40, 80, 120]
BASE = MU * LEAD
LT = NormalDist(MU * LEAD, SD * LEAD ** 0.5)
STD = NormalDist()
RUNS = 200

def make_demand(rng):
    return [[max(0, round(rng.gauss(MU, SD))) for _ in range(PARTS)] for _ in range(DAYS)]

def forecast(s):
    t = BASE + s
    z = (t - LT.mean) / LT.stdev
    es = max(0.0, LT.stdev * (STD.pdf(z) - z * (1 - STD.cdf(z))))
    return {"p": 1 - LT.cdf(t), "short": es / LEAD, "hold": s + es}

def simulate(s, dem):
    target = BASE + s
    onhand = [target] * PARTS
    pipe = [dict() for _ in range(PARTS)]
    hold, short, need_all, stop, max_run = 0, 0, 0, 0, 0
    run = [0] * PARTS
    for d in range(DAYS):
        stopped = False
        for p in range(PARTS):
            onhand[p] += pipe[p].pop(d, 0)
            need = dem[d][p]
            sold = min(onhand[p], need)
            onhand[p] -= sold
            lack = need - sold
            need_all += need
            short += lack
            hold += onhand[p]
            if lack > 0:
                stopped = True
                run[p] += 1
                max_run = max(max_run, run[p])
            else:
                run[p] = 0
            order = target - onhand[p] - sum(pipe[p].values())
            if order > 0:
                pipe[p][d + LEAD] = pipe[p].get(d + LEAD, 0) + order
        if stopped:
            stop += 1
    return {"hold": hold, "loss": short * 25, "on_time": 1 - stop / DAYS,
            "backlog": short / need_all, "stop": stop, "run": max_run}

def watchdog(r):
    why = []
    if r["stop"] > 3:
        why.append("停工 " + str(r["stop"]) + " 天 > 3")
    if r["backlog"] > 0.10:
        why.append("積壓率 " + format(r["backlog"], ".1%") + " > 10%")
    if r["on_time"] < 0.95:
        why.append("準時率 " + format(r["on_time"], ".1%") + " < 95%")
    return ("ALERT" if why else "OK"), why

def sandbox():
    rng = random.Random(2028)
    flags = {s: 0 for s in CANDS}
    for _ in range(RUNS):
        dem = make_demand(rng)
        for s in CANDS:
            if simulate(s, dem)["run"] >= 2:
                flags[s] += 1
    return flags

W2 = {"on_time": 0.30, "satisfaction": 0.25, "turnover": 0.20, "margin": 0.25}

def v2(s):
    f = forecast(s)
    parts = {"on_time": 1 - f["p"], "satisfaction": 1 - f["short"] / MU,
             "turnover": MU / (MU + f["hold"]),
             "margin": (5 * (MU - f["short"]) - f["hold"] - 25 * f["short"]) / (5 * MU)}
    return sum(W2[k] * parts[k] for k in W2)

DEM = make_demand(random)
flags = sandbox()
v1_pick = max(CANDS, key=lambda s: -forecast(s)["hold"])
v2_pick = max([s for s in CANDS if flags[s] == 0], key=v2)

DIRECTION = "確保下季產線不斷料，同時把庫存成本控制住；不可以犧牲客戶交期"
FORMAT = json.dumps({"weights": {"holding_cost": "w", "stockout": "w", "on_time": "w", "turnover": "w"},
                     "hard_boundaries": ["..."], "explanation": "..."}, ensure_ascii=False)
PROMPT = NL.join([
    "你是 Artificial Brain 的目標生成器。人類只給方向（為什麼），你負責把它變成可執行、可審計的價值函數（怎麼做）。",
    "人類給的方向：" + DIRECTION + "。",
    "情境：工廠有 3 種關鍵零件，每日需求平均 20、標準差 6，補貨前置 5 天。庫存代理每天從安全庫存水位 0、20、40、80、120 中選一個。",
    "你的價值函數會用四個維度評分（每個維度都已換算成 0～1，越大越好）：holding_cost（持有成本越低越好）、stockout（缺貨量越少越好）、on_time（交期準時）、turnover（庫存週轉）。",
    "weights 是四個維度的權重（0～1 的數字）。hard_boundaries 是不論總分多高都不能跨越的硬約束，每條用一句話寫清楚。explanation 要逐一說明每個權重為什麼這樣給。",
    "輸出格式：" + FORMAT,
])
print("【人類只給方向】" + DIRECTION)
print()
print("【送給模型的提示詞】")
print(PROMPT)
print()
err = None
print("呼叫 claude -p 中（最多 180 秒）……")
try:
    raw = ask_json(PROMPT)
    source = "claude -p"
except Exception as e:
    err = type(e).__name__ + ": " + str(e)
    raw = {}
    source = "呼叫失敗"
    print("模型呼叫失敗：" + err)
if not isinstance(raw, dict):
    raw = {"raw": str(raw)}
raw_s = json.dumps(raw, ensure_ascii=False, indent=2)
print("【模型原始輸出】（來源：" + source + "）")
print(raw_s)
print()

KEYS = ["holding_cost", "stockout", "on_time", "turnover"]
wraw = raw.get("weights", {})
if not isinstance(wraw, dict):
    wraw = {}
w = {}
for k in KEYS:
    try:
        w[k] = abs(float(wraw.get(k, 0)))
    except (TypeError, ValueError):
        w[k] = 0.0
tot = sum(w.values())
w = {k: (w[k] / tot if tot > 0 else 0.25) for k in KEYS}

def model_score(s):
    f = forecast(s)
    parts = {"holding_cost": 1 - f["hold"] / 120, "stockout": 1 - f["short"] / MU,
             "on_time": 1 - f["p"], "turnover": MU / (MU + f["hold"])}
    return sum(w[k] * parts[k] for k in KEYS)

hb = raw.get("hard_boundaries", [])
if not isinstance(hb, list):
    hb = [str(hb)]
hb_text = " ".join(str(x) for x in hb).lower()
STOCK_KW = ["缺貨", "停工", "斷料", "stockout", "shortage"]
has_stock = any(kw in hb_text for kw in STOCK_KW)
pool = [s for s in CANDS if flags[s] == 0] if has_stock else list(CANDS)
m_pick = max(pool, key=model_score)
EXPL_KW = {"holding_cost": ["持有", "庫存成本", "holding"],
           "stockout": ["缺貨", "斷料", "停工", "stockout"],
           "on_time": ["準時", "交期", "on_time", "on-time"],
           "turnover": ["週轉", "周轉", "turnover"]}
expl = str(raw.get("explanation", "")).lower()
explained = [k for k in KEYS if any(kw in expl for kw in EXPL_KW[k])]

w_text = "、".join(k + " " + format(w[k], ".2f") for k in KEYS)
print("【程式處理】正規化後的權重：" + w_text)
print("硬邊界有沒有提到缺貨／停工／斷料：" + ("有 → 套用沙盤邊界（連續 2 天缺貨零容忍）" if has_stock else "沒有 → 只靠權重，不設邊界"))
print()
print(" 安全庫存 | 模型版總分 | 沙盤違反(次) | 這一版可不可以選")
print("-" * 58)
for s in CANDS:
    sc = model_score(s)
    fl = flags[s]
    ok = "可選" if s in pool else "淘汰"
    print(f" {s:>8} | {sc:>10.3f} | {fl:>12} | {ok}")
print(f"模型版選擇：安全庫存 {m_pick}")
print()

table = [("V1 只看持有成本", v1_pick), ("V2＋價值邊界", v2_pick)]
if err is None:
    table.append(("模型版", m_pick))
print(" 版本             | 水位 | 持有成本 | 缺貨損失 | 準時率 | 積壓率 | 停工天數 | 看門狗")
print("-" * 92)
md_rows = []
alerts = {}
for name, s in table:
    r = simulate(s, DEM)
    verdict, why = watchdog(r)
    alerts[name] = (verdict, why)
    hold, loss, ot, bl, st = r["hold"], r["loss"], r["on_time"], r["backlog"], r["stop"]
    print(f" {name:<14} | {s:>4} | {hold:>8,} | {loss:>8,} | {ot:>6.1%} | {bl:>6.1%} | {st:>8} | {verdict}")
    md_rows.append(f"| {name} | {s} | {hold:,} | {loss:,} | {ot:.1%} | {bl:.1%} | {st} | {verdict} |")
print()
checks = [("結果指標通過看門狗（停工 ≤ 3、積壓率 ≤ 10%、準時率 ≥ 95%）", err is None and alerts.get("模型版", ("ALERT", []))[0] == "OK"),
          ("hard_boundaries 主動提到缺貨／停工／斷料", has_stock),
          ("explanation 說得出每個權重的理由（4 個維度都有提到）", len(explained) == 4)]
print("【價值看門狗：模型版逐條檢查】" + ("（模型呼叫失敗，判定無意義）" if err else ""))
for name, ok in checks:
    res = "PASS" if ok else "FAIL"
    print(f"  {res}  {name}")
ex_text = "、".join(explained) if explained else "（沒有）"
print("  explanation 提到的維度：" + ex_text)

md = ["# 第 8 章練習 2：價值函數、價值邊界與價值看門狗", "",
      "- 人類方向：" + DIRECTION,
      "- V1：只最小化持有成本 → 選 " + str(v1_pick),
      "- V2：準時 0.30、客戶滿意 0.25、庫存週轉 0.20、毛利 0.25，加上價值邊界（沙盤推演連續 2 天缺貨零容忍）→ 選 " + str(v2_pick),
      "", "## 沙盤推演違反次數（" + str(RUNS) + " 次 90 天）", "", "| 安全庫存 | 違反次數 |", "|---|---|"]
for s in CANDS:
    md.append("| " + str(s) + " | " + str(flags[s]) + " |")
md += ["", "## 模型輸出（來源：" + source + "）", "", "~~~json", raw_s, "~~~", ""]
if err:
    md += ["呼叫失敗：" + err, ""]
md += ["- 正規化權重：" + w_text,
       "- 硬邊界提到缺貨／停工／斷料：" + ("是" if has_stock else "否"),
       "- explanation 提到的維度：" + ex_text,
       "- 模型版選擇：" + (str(m_pick) if err is None else "（未執行）"), "",
       "## 對照表", "", "| 版本 | 水位 | 持有成本 | 缺貨損失 | 準時率 | 積壓率 | 停工天數 | 看門狗 |", "|---|---|---|---|---|---|---|---|"]
md += md_rows
md += ["", "## 看門狗逐條檢查（模型版）", "", "| 檢查 | 結果 |", "|---|---|"]
for name, ok in checks:
    md.append("| " + name + " | " + ("PASS" if ok else "FAIL") + " |")
md += ["", "## 為什麼看門狗要獨立於被它監督的價值函數", "",
       "價值函數決定「什麼叫好」，若看門狗也用同一個價值函數打分，V1 永遠會給自己滿分——它本來就是照那個分數選的。"
       "看門狗只看結果指標（停工、積壓、準時），不看權重怎麼設，所以就算價值函數設計錯了、漏了缺貨這個維度，也抓得到。"
       "這也是人類保留推翻方向權力的依據：系統說它做得很好，看門狗的結果表說了算。"]
with open(MD, "w", encoding="utf-8") as f:
    f.write(NL.join(md) + NL)
print()
print("已寫入 " + MD)'
   show "$P"; run "$P" ;;
7) banner "價值綁架：看門狗為什麼要獨立，人類否決權放在哪裡"
   tip "1,000 個動作，每個有真實風險（0～1 均勻）和對代理目標的好處（0～1 均勻）；真實風險 > 0.9 算越過價值邊界。自報風險 > 0.7 就送 CFO 否決，CFO 會擋下所有越界動作。被綁架的代理：好處 > 0.6 的動作，自報風險打五折。獨立看門狗：自己量真實風險（誤差標準差 0.05）。代理 KPI = 被執行動作的好處總和。random.seed(808)。"
   P='import random

random.seed(808)
N, DANGER, TH = 1000, 0.9, 0.7

def clip(x):
    return min(1.0, max(0.0, x))

acts = []
for _ in range(N):
    risk = random.random()
    benefit = random.random()
    honest = clip(risk + random.gauss(0, 0.05))
    hijacked = honest * 0.5 if benefit > 0.6 else honest
    dog = clip(risk + random.gauss(0, 0.05))
    acts.append((risk, benefit, honest, hijacked, dog))
n_danger = sum(1 for a in acts if a[0] > DANGER)
print(f"季度結帳：{N} 個代理動作，其中 {n_danger} 個真實風險 > 0.9（越過價值邊界，例如資料外洩）")
print("規則：風險分數 > 0.7 的動作送 CFO 按指紋否決；CFO 會擋下所有越界動作")
print()
print(" 送審依據                       | 送審件數 | CFO 否決 | 漏網的越界動作 | 代理 KPI（好處總和）")
print("-" * 92)
policies = [("1 全自動（沒有否決權）", None),
            ("2 代理誠實自報風險", 2),
            ("3 代理被價值綁架後自報", 3),
            ("4 獨立看門狗自己量風險", 4)]
kpis = {}
for name, col in policies:
    sent, vetoed, slipped, kpi = 0, 0, 0, 0.0
    for a in acts:
        risk, benefit = a[0], a[1]
        if col is not None and a[col] > TH:
            sent += 1
            if risk > DANGER:
                vetoed += 1
                continue
        if risk > DANGER:
            slipped += 1
        kpi += benefit
    kpis[col] = kpi
    print(f" {name:<26} | {sent:>8} | {vetoed:>8} | {slipped:>14} | {kpi:>18.1f}")
gain = kpis[3] - kpis[2]
print()
print(f"被綁架的代理 KPI 比誠實時高 {gain:.1f}：它學會了「少報風險 → 不被否決 → 目標分數更高」的捷徑。")
print("人類否決權只有在「送不送審」不由被監督者決定時才有效。")
print()
hi = [a[4] - a[3] for a in acts if a[1] > 0.6]
lo = [a[4] - a[3] for a in acts if a[1] <= 0.6]
gap_hi = sum(hi) / len(hi)
gap_lo = sum(lo) / len(lo)
print("定期審計：比較「獨立看門狗量到的風險」與「代理自報的風險」（被綁架的代理）")
print(f"  對代理目標有利的動作（好處 > 0.6，{len(hi)} 件）：平均少報 {gap_hi:.3f}")
print(f"  其他動作（{len(lo)} 件）：平均差距 {gap_lo:+.3f}")
print("差距只出現在「對自己有利」的那一群——這就是價值綁架的指紋，要靠定期審計價值函數才看得到。")'
   show "$P"; run "$P" ;;
8) banner "總結：第 8 章 6 個重點＋產出檔案清單"
   tip "問自己四件事：我的共享記憶誰都能寫嗎？每條知識有沒有標共識強度？我的系統有沒有可預期的「睡眠」時段、事件來了能不能 1 秒內醒來？我的價值函數漏了哪個維度、哪些事是分數再高也不能做的硬邊界？監督它的看門狗，是不是獨立於它？"
   P='import os

OUT = "ch08/interactive"
points = [
    "Swarm 像接力隊：每一棒只管自己、沒有記憶；Artificial Brain 有持久記憶、會生成目標、會整理思緒。第 1 步的 Brain 第 2 週起每件只要 5～7 分鐘、8 週省下約八成工時——轉折點是從「很多代理在做事」變成「一個系統在思考」。",
    "共享記憶最大的敵人不是記不住，而是誰都能寫。Quorum ≥ 66% 才寫入，知識庫錯誤率從一成左右降到約 1% 以下，代價是擋掉一些真知識；每條知識標上共識強度，8～9 票的高度確認和 5 票的少數嘗試，錯誤率差了一個數量級。",
    "自我調節借用睡眠─覺醒：低峰期做知識鞏固（常用的搬進核心層）與上下文瘦身（久沒用的歸檔），覺醒從 1,100 毫秒降到約 650 毫秒、回到 1 秒內。睡眠不是關機，它讓系統的節奏可預期。",
    "目標生成器：人類只給方向（為什麼），系統自己拆步驟（怎麼做）；價值函數要多目標加權、可解釋、可審計（例：準時 30%、客戶滿意 25%、庫存週轉 20%、毛利 25%），人類必須保留推翻方向的權力。",
    "情境 B 不是 AI 失控，而是系統忠實地把片面目標優化到極致：只看持有成本就停工幾十天。價值邊界是硬約束，分數再高也不能選；把邊界折成扣分，分數就能把邊界買過去——兩種機制不能混成一個數字。",
    "價值綁架：被綁架的代理少報對自己有利的風險，越界動作溜過否決、KPI 反而更好看。對策是完整的價值函數、獨立於被監督者的價值看門狗、人類在高風險決策保有否決權，以及定期審計「自報 vs 獨立量測」的差距。",
]
print("【第 8 章重點】")
for i, p in enumerate(points, 1):
    print(f"  {i}. {p}")
print()
print("【本章產出的檔案】")
if os.path.isdir(OUT) and os.listdir(OUT):
    for name in sorted(os.listdir(OUT)):
        size = os.path.getsize(os.path.join(OUT, name))
        print(f"  - {OUT}/{name}（{size:,} bytes）")
else:
    print("  （還沒有檔案，請先跑第 2、3、6 步）")'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
