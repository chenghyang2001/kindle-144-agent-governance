#!/bin/bash
# K144 第 2 章互動演練：Agent Swarm 的結構座標——角色、顆粒度與通訊機制，一次跑一步
# 用法：bash ch02.sh <步驟 1-8>
# 呼叫模型：只有第 7 步會呼叫模型 1 次（llm_agent.ask_json，走 claude -p）；其他步全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch02/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K144 第 2 章｜Agent Swarm 的結構座標　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "角色三原色地圖＋責任鏈承重"
   tip "跨境供應鏈面板上 12 個代理：1 個 Planner 拆局、9 個 Worker 收球、2 個 Monitor 盯哨。先看哪個流程沒人盯，再看一個代理走音會讓 12 段鏈掉多少成功率。"
   P='import random

random.seed(144)
FLOWS = ["報價", "庫存", "物流", "帳務"]
AGENTS = [
    ("A01", "planner", "全局", "拆局：切幾塊、先後、誰有空"),
    ("A02", "worker", "報價", "抓價格與折扣"),
    ("A03", "worker", "報價", "計算稅率"),
    ("A04", "worker", "庫存", "查庫存"),
    ("A05", "worker", "庫存", "預留庫存"),
    ("A06", "worker", "物流", "訂艙"),
    ("A07", "worker", "物流", "報關文件"),
    ("A08", "worker", "帳務", "開帳單"),
    ("A09", "worker", "帳務", "匯率換算"),
    ("A10", "monitor", "報價", "盯報價延遲與錯誤率"),
    ("A11", "monitor", "庫存", "盯庫存水位趨勢"),
    ("A12", "worker", "庫存", "查庫存"),
]
planners = [a for a in AGENTS if a[1] == "planner"]
print("【誰下決策、誰搬資料、誰看異常】跨境供應鏈面板，12 個代理")
print("全局 Planner：" + "、".join(a[0] for a in planners) + f"（{len(planners)} 個，負責拆局）")
print()
print(" 流程 | Worker             | Monitor     | 檢查結果")
print("-" * 64)
for flow in FLOWS:
    w = [a for a in AGENTS if a[2] == flow and a[1] == "worker"]
    m = [a for a in AGENTS if a[2] == flow and a[1] == "monitor"]
    jobs = [a[3] for a in w]
    dup = sorted({j for j in jobs if jobs.count(j) > 1})
    issues = []
    if not m:
        issues.append("⚠ 沒有 Monitor（空白區）")
    if dup:
        issues.append("⚠ Worker 重疊：" + "、".join(dup))
    text = "；".join(issues) if issues else "OK"
    wid = ",".join(a[0] for a in w)
    mid = ",".join(a[0] for a in m) or "—"
    print(f" {flow} | {len(w)} 個 ({wid:<12}) | {len(m)} 個 ({mid:<3}) | {text}")

print()
print("【責任鏈承重】一張訂單依序經過 12 個代理，每段成功率 0.99")

def theory(ps):
    r = 1.0
    for p in ps:
        r *= p
    return r

def simulate(ps, n=10000):
    return sum(1 for _ in range(n) if all(random.random() < p for p in ps))

base = [0.99] * 12
detuned = list(base)
detuned[5] = 0.70                      # A06 訂艙走音
watched = list(detuned)
watched[5] = 0.70 + 0.30 * 0.70        # Monitor 回流數據、Planner 改派備援重做一次
cases = [("全部正常", base), ("A06 訂艙走音（0.70）", detuned), ("走音＋Monitor 回報、Planner 改派", watched)]
print(" 情境                             | 理論成功率 | 模擬 10,000 單成功數")
print("-" * 68)
for name, ps in cases:
    print(f" {name:<30} | {theory(ps):>9.2%} | {simulate(ps):>8,}")
print()
print("一把小號走音（1/12 的代理）就讓整段成功率掉約 26 個百分點；")
print("而 A06 正好在「物流」——上表沒有 Monitor 的空白區，沒人會把這個數據回流給 Planner。")'
   show "$P"; run "$P" ;;
2) banner "陷阱：沒有 TTL 的幽靈代理"
   tip "每個 tick 進來 2 個代理，初始化、競價各 1 tick，然後鎖定一個 GPU 槽跑 3～8 tick 再釋放。15% 的代理會在鎖定後崩潰、不再回報。比較「沒有 TTL」和「TTL=10 tick 強制清場」。兩種策略用的是同一批代理。"
   P='import random

random.seed(144)
TICKS, SLOTS, TTL = 60, 20, 10
agents = []
for t in range(TICKS):
    for _ in range(2):
        agents.append({"arrive": t, "dur": random.randint(3, 8), "crash": random.random() < 0.15})
n_crash = sum(1 for a in agents if a["crash"])

def simulate(ttl):
    held = []          # (預計釋放時刻, 是否崩潰成幽靈, 鎖定時刻)
    done = rejected = reclaimed = 0
    timeline = {}
    for t in range(TICKS):
        keep = []
        for end, ghost, start in held:          # 檢查點 4：釋放
            if not ghost and end <= t:
                done += 1
            elif ghost and ttl is not None and t - start >= ttl:
                reclaimed += 1                  # TTL 到期，強制清場
            else:
                keep.append((end, ghost, start))
        held = keep
        for a in agents:                        # 初始化 1 tick → 競價 1 tick → 鎖定
            if a["arrive"] + 2 == t:
                if len(held) < SLOTS:
                    held.append((t + a["dur"], a["crash"], t))
                else:
                    rejected += 1               # 競價失敗：沒有空的 GPU 槽
        timeline[t] = (len(held), sum(1 for e, g, s in held if g))
    return done, rejected, reclaimed, timeline

no_ttl = simulate(None)
with_ttl = simulate(TTL)
print(f"代理 {len(agents)} 個（每 tick 進來 2 個），其中 {n_crash} 個會在鎖定後崩潰、不再回報；GPU 槽 {SLOTS} 個")
print()
print(" tick | 無 TTL：佔用 / 幽靈 | TTL=10：佔用 / 幽靈")
print("-" * 48)
for t in (5, 15, 25, 35, 45, 55, 59):
    a, b = no_ttl[3][t], with_ttl[3][t]
    print(f" {t:>4} | {a[0]:>9} / {a[1]:<7} | {b[0]:>9} / {b[1]:<7}")
print()
print(" 策略   | 完成任務 | 競價被拒 | TTL 回收幽靈 | 結束時幽靈佔槽")
print("-" * 62)
for name, r in (("無 TTL", no_ttl), ("TTL=10", with_ttl)):
    print(f" {name:<6} | {r[0]:>8} | {r[1]:>8} | {r[2]:>12} | {r[3][59][1]:>12}")
print()
print("沒有 TTL：幽靈只增不減，資源池被塞滿後，健康的新代理反而競價失敗。")
print("有 TTL：鎖定是一份會過期的租約，崩潰的代理最多佔 10 tick 就被清場。")'
   show "$P"; run "$P" ;;
3) banner "顆粒度是槓桿：通訊稅 vs 錯誤疊乘"
   tip "一件 1200 秒、48,000 tokens、64 步推理的工作，8 個 Worker，每塊通訊稅 6 秒。推理第 1 步錯誤率 0.05%，之後每多一步乘 1.3。這一步沒有亂數，數字每次都一樣。"
   P='TOTAL_WORK, TOTAL_TOKENS, TOTAL_STEPS = 1200, 48000, 64
WORKERS, COMM = 8, 6
E0, GROW = 0.0005, 1.3
MAX_TOK, MAX_COT = 8000, 10

def chunk_success(steps):
    p = 1.0
    for i in range(steps):
        p *= 1 - min(1.0, E0 * GROW ** i)
    return p

print(f"把一件 {TOTAL_WORK} 秒、{TOTAL_TOKENS:,} tokens、{TOTAL_STEPS} 步推理的審核工作拆成 k 塊；{WORKERS} 個 Worker、每塊通訊稅 {COMM} 秒")
print("推理每多一步，錯誤率乘 1.3（第 1 步 0.05%）")
print()
print("   k | 每塊tokens | 每塊推理步 | 原子? | 完工秒數 | 通訊稅占比 | 整條成功率 | 每成功一單期望秒數")
print("-" * 98)
best = None
for k in (1, 2, 4, 8, 16, 32, 64):
    tok, steps = TOTAL_TOKENS // k, TOTAL_STEPS // k
    atomic = "是" if tok <= MAX_TOK and steps <= MAX_COT else "否"
    rounds = -(-k // WORKERS)
    makespan = rounds * TOTAL_WORK / k + COMM * k
    succ = chunk_success(steps) ** k
    exp_t = makespan / succ if succ > 0 else float("inf")
    if best is None or exp_t < best[1]:
        best = (k, exp_t)
    exp_s = "∞（幾乎必錯）" if succ == 0 else f"{exp_t:,.0f}"
    print(f"{k:>4} | {tok:>10,} | {steps:>10} | {atomic:^5} | {makespan:>8,.0f} | {COMM * k / makespan:>10.1%} | {succ:>10.1%} | {exp_s:>14}")
print()
print(f"甜蜜點：k={best[0]}（每成功一單約 {best[1]:,.0f} 秒）")
print("k 太小：單塊推理太長，錯誤疊乘到整件必錯；k 太大：通訊稅吃掉平行度。")
print(f"k={best[0]} 也正好是第一個同時滿足「tokens ≤ {MAX_TOK}、推理 ≤ {MAX_COT} 步」的切法——閾值讓 Planner 可以被程式檢查。")'
   show "$P"; run "$P" ;;
4) banner "拆與合靠閾值：原子性規則＋Jaccard 合併"
   tip "T4「查信用額度並決定是否核准」和 T8「整體風險判斷」故意寫得太大；T5、T6 兩個匯率任務關鍵詞高度重疊。最後一張表把門檻放寬、收緊各試一次。"
   P='MAX_TOK, MAX_COT, JAC = 8000, 10, 0.6
TASKS = [
    ("T1", "抓價格", 3000, 4, ["價格", "報價單", "幣別"]),
    ("T2", "驗證稅率", 5200, 7, ["稅率", "國別", "報價單"]),
    ("T3", "計算折扣", 4800, 6, ["折扣", "價格", "報價單"]),
    ("T4", "查信用額度並決定核准", 14000, 18, ["信用額度", "客戶", "核准"]),
    ("T5", "匯率換算", 2600, 3, ["匯率", "幣別", "換算"]),
    ("T6", "即時匯率換算", 2200, 2, ["匯率", "幣別", "換算", "即時"]),
    ("T7", "彙整審核報告", 9000, 6, ["報告", "彙整", "審核"]),
    ("T8", "整體風險判斷", 7000, 23, ["風險", "審核", "核准"]),
]
TOK = {t[0]: t[2] for t in TASKS}
COT = {t[0]: t[3] for t in TASKS}

def split(tid, tok, cot, max_tok, max_cot):
    if tok <= max_tok and cot <= max_cot:
        return [(tid, tok, cot)]
    half_tok, half_cot = tok // 2, (cot + 1) // 2
    return split(tid + "a", half_tok, half_cot, max_tok, max_cot) + split(tid + "b", half_tok, half_cot, max_tok, max_cot)

def jaccard(a, b):
    a, b = set(a), set(b)
    return len(a & b) / len(a | b)

print(f"【拆】門檻：tokens > {MAX_TOK} 或推理 > {MAX_COT} 步 → 對半再拆")
print(" id | 子任務               | tokens | 推理步 | 判定")
print("-" * 76)
for tid, goal, tok, cot, kw in TASKS:
    pieces = split(tid, tok, cot, MAX_TOK, MAX_COT)
    if len(pieces) == 1:
        verdict = "PASS 原子任務"
    else:
        why = []
        if tok > MAX_TOK:
            why.append("tokens 超標")
        if cot > MAX_COT:
            why.append("推理步超標")
        verdict = "需再拆（" + "、".join(why) + f"）→ {len(pieces)} 塊：" + ",".join(p[0] for p in pieces)
    print(f" {tid} | {goal:<12} | {tok:>6,} | {cot:>6} | {verdict}")

print()
print(f"【合】門檻：關鍵詞 Jaccard ≥ {JAC}，且合併後仍是原子任務")
pairs = []
for i in range(len(TASKS)):
    for j in range(i + 1, len(TASKS)):
        s = jaccard(TASKS[i][4], TASKS[j][4])
        if s > 0:
            pairs.append((s, TASKS[i][0], TASKS[j][0]))
pairs.sort(reverse=True)
for s, a, b in pairs[:6]:
    mark = "← 可合併候選" if s >= JAC else ""
    print(f"  {a}-{b}  Jaccard={s:.2f} {mark}")

print()
print("【改門檻看結果】Jaccard 固定 0.6")
print(" tokens上限 | 推理上限 | 拆完任務數 | 可合併對數 | 最終任務數 | 平均tokens/任務")
print("-" * 80)
total_tok = sum(TOK.values())
for mt, mc in ((16000, 20), (8000, 10), (4000, 5)):
    n = sum(len(split(t[0], t[2], t[3], mt, mc)) for t in TASKS)
    ok = [(a, b) for s, a, b in pairs if s >= JAC and TOK[a] + TOK[b] <= mt and COT[a] + COT[b] <= mc]
    final = n - len(ok)
    print(f" {mt:>10,} | {mc:>8} | {n:>10} | {len(ok):>10} | {final:>10} | {total_tok / final:>12,.0f}")
print()
print("門檻放寬 → 任務少但單塊又大又長（錯誤疊乘）；門檻收緊 → 任務暴增（通訊稅），連合併都被擋下。")
print("拆與合都看閾值、不靠感覺：同一份清單，誰來跑都得到同一個答案。")'
   show "$P"; run "$P" ;;
5) banner "練習 1A：Message Bus 的廣播風暴"
   tip "N 取 10、30、100、300，模擬 10 秒；每秒每個代理以機率 0.5 產生 1～60 則事件，每則帶 6 種能力標籤之一，每個代理只有其中 2 種能力。結果寫到 ch02/interactive/bus_vs_blackboard.csv。匯流排還有另一個暗礁是單點故障——要靠叢集化、本地緩衝、直連備援，總結時再提。"
   rm -f "$WORK/bus_vs_blackboard.csv"
   P='import csv
import os
import random
from collections import deque

random.seed(144)
OUT = "ch02/interactive"
os.makedirs(OUT, exist_ok=True)
HEADER = ["section", "N", "strategy", "deliveries", "irrelevant_ratio", "backlog", "lost_updates", "retries", "escalated"]
NS = [10, 30, 100, 300]
SECONDS, TAGS, CAPS, RATE = 10, 6, 2, 30

def simulate(n):
    caps = [set(random.sample(range(TAGS), CAPS)) for _ in range(n)]
    holders = [sum(1 for c in caps if t in c) for t in range(TAGS)]
    events = []
    for s in range(SECONDS):
        sec = []
        for a in range(n):
            k = random.randint(1, 60) if random.random() < 0.5 else 0
            sec.append([random.randrange(TAGS) for _ in range(k)])
        events.append(sec)

    def relevant(a, tag):
        return holders[tag] - (1 if tag in caps[a] else 0)

    total = irr = 0                                   # 1) broadcast：送給其他所有代理
    for sec in events:
        for a, tags in enumerate(sec):
            for tag in tags:
                total += n - 1
                irr += (n - 1) - relevant(a, tag)
    res = {"broadcast": (total, irr / total if total else 0.0, 0)}

    queues = [deque() for _ in range(n)]              # 2)、3) 漏桶：每代理每秒最多發 RATE 則
    rl_total = rl_irr = sm_total = 0
    for sec in events:
        for a, tags in enumerate(sec):
            q = queues[a]
            q.extend(tags)
            for _ in range(min(RATE, len(q))):
                tag = q.popleft()
                rel = relevant(a, tag)
                rl_total += n - 1
                rl_irr += (n - 1) - rel
                sm_total += rel
    backlog = sum(len(q) for q in queues)
    res["rate_limit"] = (rl_total, rl_irr / rl_total if rl_total else 0.0, backlog)
    res["smart_subscribe"] = (sm_total, 0.0, backlog)
    return res

print(f"模擬 {SECONDS} 秒；每秒每代理以機率 0.5 產生 1～60 則事件；{TAGS} 種能力標籤，每代理具備 {CAPS} 種；速率上限 {RATE} 則/秒")
print()
print("    N | 策略            |     總投遞次數 | 無關投遞比例 | 積壓則數 | 對 broadcast")
print("-" * 82)
rows, summary = [], {}
for n in NS:
    res = simulate(n)
    base = res["broadcast"][0]
    for name in ("broadcast", "rate_limit", "smart_subscribe"):
        total, irr, backlog = res[name]
        summary[(n, name)] = total
        print(f"{n:>5} | {name:<15} | {total:>14,} | {irr:>12.1%} | {backlog:>8,} | {total / base:>11.1%}")
        rows.append(["storm", n, name, total, round(irr, 4), backlog, "", "", ""])
    print()
growth = summary[(300, "broadcast")] / summary[(30, "broadcast")]
print(f"broadcast：N 從 30 → 300（10 倍），投遞量變成 {growth:.0f} 倍（N² 理論值 {300 * 299 / (30 * 29):.0f} 倍）")
print()
print("【改參數】smart_subscribe 的投遞量約是 broadcast 的「每代理能力數 / 標籤數」：")
for tags, caps in ((6, 2), (12, 2), (30, 1)):
    print(f"  標籤 {tags:>2} 種、每代理 {caps} 種 → 約 {caps / tags:.1%}")
print("  → 能力切得越細、訂閱越精準，才會出現「少一個數量級」；本練習的 6 選 2 只能省到約三分之一。")

path = os.path.join(OUT, "bus_vs_blackboard.csv")
with open(path, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(HEADER)
    w.writerows(rows)
print()
print("已寫入", path, "（黑板競寫的兩列會在第 6 步補上）")'
   show "$P"; run "$P" ;;
6) banner "練習 1B＋C：Blackboard 競寫與版本戳"
   tip "報告有 price、tax、discount、credit、fx 5 個欄位，每個 Worker 對每欄寫 200 次，共 8,000 次；每次讀到過期版本的機率 30%。報告總和應該是 8,000，少掉的就是被吃掉的更新。另外試過期機率 0.1 和 0.5。"
   P='import csv
import os
import random

random.seed(144)
OUT = "ch02/interactive"
PATH = os.path.join(OUT, "bus_vs_blackboard.csv")
os.makedirs(OUT, exist_ok=True)
HEADER = ["section", "N", "strategy", "deliveries", "irrelevant_ratio", "backlog", "lost_updates", "retries", "escalated"]
WORKERS, WRITES, MAX_RETRY = 8, 200, 3
FIELDS = ["price", "tax", "discount", "credit", "fx"]
EXPECTED = WORKERS * len(FIELDS) * WRITES
ops = [(w, f) for w in range(WORKERS) for f in FIELDS for _ in range(WRITES)]
random.shuffle(ops)

def overwrite(p):
    value = {f: 0 for f in FIELDS}
    for w, f in ops:
        stale = value[f] > 0 and random.random() < p
        value[f] = (value[f] - 1 if stale else value[f]) + 1   # 拿舊值算完直接蓋回去
    return 0, 0, sum(value.values())

def version_stamp(p):
    value = {f: 0 for f in FIELDS}
    retries = escalated = 0
    for w, f in ops:
        for attempt in range(MAX_RETRY + 1):
            stale = value[f] > 0 and random.random() < p
            if not stale:                       # 版本號相符才寫入
                value[f] += 1
                break
            if attempt < MAX_RETRY:
                retries += 1                    # 版本不符：重讀重寫
        else:
            escalated += 1                      # 重試 3 次仍失敗：退回 Planner
    return retries, escalated, sum(value.values())

results = {}
for p in (0.3, 0.1, 0.5):
    results[p] = {"overwrite": overwrite(p), "version_stamp": version_stamp(p)}

print(f"{WORKERS} 個 Worker × {len(FIELDS)} 個欄位 × 各寫 {WRITES} 次 = {EXPECTED:,} 次寫入；讀到過期版本的機率 30%")
print()
print(" 做法          | 遺失更新 | 重試總次數 | 退回 Planner | 報告總和（應為 8,000）")
print("-" * 78)
main = {}
for name in ("overwrite", "version_stamp"):
    retries, esc, total = results[0.3][name]
    lost = EXPECTED - total - esc               # 沒寫進去、也沒退回 Planner 的，才叫遺失
    main[name] = (lost, retries, esc)
    print(f" {name:<13} | {lost:>8,} | {retries:>10,} | {esc:>12,} | {total:>10,}")

print()
print("【改參數】過期機率 p 變大時")
print("   p  | overwrite 遺失 | version_stamp 重試 | 退回 Planner")
print("-" * 60)
for p in (0.1, 0.3, 0.5):
    o, v = results[p]["overwrite"], results[p]["version_stamp"]
    print(f" {p:.1f}  | {EXPECTED - o[2]:>14,} | {v[0]:>18,} | {v[1]:>12,}")

rows = []
if os.path.exists(PATH):
    with open(PATH, encoding="utf-8", newline="") as f:
        rows = [r for r in csv.DictReader(f) if r.get("section") != "blackboard"]
storm = [r for r in rows if r.get("section") == "storm"]
for name in ("overwrite", "version_stamp"):
    lost, retries, esc = main[name]
    rows.append({"section": "blackboard", "N": WORKERS, "strategy": name, "deliveries": "", "irrelevant_ratio": "",
                 "backlog": "", "lost_updates": lost, "retries": retries, "escalated": esc})
with open(PATH, "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=HEADER)
    w.writeheader()
    w.writerows(rows)
print()
print("已寫入", PATH, f"（共 {len(rows)} 列資料）")
print()
s300 = [r for r in storm if r["N"] == "300"]
if s300:
    best = min(s300, key=lambda r: int(r["deliveries"]))
    bc = [r for r in s300 if r["strategy"] == "broadcast"][0]
    name, num = best["strategy"], int(best["deliveries"])
    ratio = num / int(bc["deliveries"])
    print(f"結論 1：N=300 時投遞量最少的是 {name}（{num:,} 次，約 broadcast 的 {ratio:.0%}，無關投遞 0%）")
else:
    print("結論 1：找不到第 5 步的廣播風暴結果，請先跑第 5 步")
ow, vs = main["overwrite"], main["version_stamp"]
print(f"結論 2：版本戳把遺失更新從 {ow[0]:,} 降到 {vs[0]}，代價是 {vs[1]:,} 次重試、{vs[2]} 次退回 Planner（不是悄悄丟掉）")'
   show "$P"; run "$P" ;;
7) banner "練習 2：真實 Planner 拆任務，用程式規則驗收"
   tip "會呼叫模型 1 次（ask_json，走 claude -p，最多 180 秒）。先跑離線自我測試：假計畫裡有超標任務、沒輸出欄位的 Worker、指向不存在的 T9、T4↔T5 互相依賴，而且沒有 Monitor。報告寫到 ch02/interactive/planner_granularity.md。"
   rm -f "$WORK/planner_granularity.md"
   P='import json
import os
import sys

sys.path.insert(0, os.getcwd())
from llm_agent import ask_json

OUT = "ch02/interactive"
os.makedirs(OUT, exist_ok=True)
MAX_TOK, MAX_COT, JAC = 8000, 10, 0.6
ROLES = ("planner", "worker", "monitor")
MEDDLE = ("執行", "修改", "修正", "核准", "改派", "覆寫")

def to_int(x):
    try:
        return int(float(x))
    except (TypeError, ValueError):
        return None

def as_list(x):
    if isinstance(x, list):
        return [str(v).strip() for v in x if str(v).strip()]
    if x is None or str(x).strip() == "":
        return []
    return [str(x).strip()]

def normalize(plan):
    raw = plan.get("tasks", []) if isinstance(plan, dict) else []
    out = []
    for t in raw:
        if isinstance(t, dict):
            out.append({
                "id": str(t.get("id", "")).strip(),
                "role": str(t.get("role", "")).strip().lower(),
                "goal": str(t.get("goal", "")).strip(),
                "input_schema": as_list(t.get("input_schema")),
                "output_schema": as_list(t.get("output_schema")),
                "est_tokens": to_int(t.get("est_tokens")),
                "cot_steps": to_int(t.get("cot_steps")),
                "depends_on": as_list(t.get("depends_on")),
                "keywords": as_list(t.get("keywords")),
            })
    return out

def jaccard(a, b):
    a, b = set(a), set(b)
    return len(a & b) / len(a | b) if (a or b) else 0.0

def success(cot):
    return 0.99 ** (1.3 ** ((cot or 0) / 10))      # 示意公式

def check(tasks):
    rows = []
    by_id = {t["id"]: t for t in tasks}
    for t in tasks:
        tid, tok, cot = t["id"], t["est_tokens"], t["cot_steps"]
        if tok is None or cot is None:
            rows.append((tid, "1 原子性", "FAIL", "est_tokens 或 cot_steps 不是整數"))
        elif tok > MAX_TOK or cot > MAX_COT:
            rows.append((tid, "1 原子性", "FAIL", "需再拆（tokens=" + str(tok) + "，cot=" + str(cot) + "）"))
        else:
            rows.append((tid, "1 原子性", "PASS", "tokens=" + str(tok) + "，cot=" + str(cot)))
        if t["role"] not in ROLES:
            rows.append((tid, "2 契約", "FAIL", "未知角色：" + t["role"]))
        elif t["role"] == "worker":
            if t["input_schema"] and t["output_schema"]:
                rows.append((tid, "2 契約", "PASS", "輸入輸出都有欄位"))
            else:
                rows.append((tid, "2 契約", "FAIL", "worker 的 input_schema 或 output_schema 是空的"))
        elif t["role"] == "monitor":
            hits = [w for w in MEDDLE if w in t["goal"]]
            if hits:
                rows.append((tid, "3 角色三原色", "WARN", "monitor 目標含「" + "、".join(hits) + "」，可能插手執行"))
        missing = [d for d in t["depends_on"] if d not in by_id]
        if missing:
            rows.append((tid, "4 依賴圖", "FAIL", "指向不存在的 id：" + ",".join(missing)))
    n_mon = sum(1 for t in tasks if t["role"] == "monitor")
    rows.append(("（整體）", "3 角色三原色", "PASS" if n_mon else "FAIL", ("monitor " + str(n_mon) + " 個") if n_mon else "沒人盯哨"))
    color, cycle = {}, []

    def dfs(u, stack):
        color[u] = 1
        stack.append(u)
        for d in by_id[u]["depends_on"]:
            if d not in by_id:
                continue
            if color.get(d) == 1 and not cycle:
                cycle.extend(stack[stack.index(d):] + [d])
            elif color.get(d) is None:
                dfs(d, stack)
        stack.pop()
        color[u] = 2

    for tid in by_id:
        if tid not in color:
            dfs(tid, [])
    rows.append(("（整體）", "4 依賴圖", "FAIL" if cycle else "PASS", ("有環：" + " → ".join(cycle)) if cycle else "無環"))
    workers = [t for t in tasks if t["role"] == "worker"]
    merges = []
    for i in range(len(workers)):
        for j in range(i + 1, len(workers)):
            s = jaccard(workers[i]["keywords"], workers[j]["keywords"])
            if s >= JAC:
                merges.append((workers[i]["id"], workers[j]["id"], round(s, 2)))
    crit = None
    if not cycle and by_id:
        memo = {}

        def worst(u):
            if u not in memo:
                best = (1.0, [])
                for d in by_id[u]["depends_on"]:
                    if d in by_id:
                        cand = worst(d)
                        if cand[0] < best[0]:
                            best = cand
                memo[u] = (success(by_id[u]["cot_steps"]) * best[0], best[1] + [u])
            return memo[u]

        crit = min((worst(u) for u in by_id), key=lambda x: x[0])
    overall = "FAIL" if any(r[2] == "FAIL" for r in rows) else "PASS"
    return rows, merges, crit, overall

# 一、離線自我測試：規則要先抓得到每一種錯
demo = {"tasks": [
    {"id": "T1", "role": "planner", "goal": "拆單", "input_schema": ["報價單"], "output_schema": ["子任務清單"],
     "est_tokens": 1500, "cot_steps": 4, "depends_on": [], "keywords": ["拆單", "排程"]},
    {"id": "T2", "role": "worker", "goal": "一次審完全部欄位", "input_schema": ["報價單"], "output_schema": ["審核結果"],
     "est_tokens": 12000, "cot_steps": 14, "depends_on": ["T1"], "keywords": ["價格", "稅率", "折扣"]},
    {"id": "T3", "role": "worker", "goal": "查信用額度", "input_schema": ["客戶ID"], "output_schema": [],
     "est_tokens": 2000, "cot_steps": 3, "depends_on": ["T9"], "keywords": ["信用額度", "客戶"]},
    {"id": "T4", "role": "worker", "goal": "查匯率", "input_schema": ["幣別"], "output_schema": ["匯率"],
     "est_tokens": 1000, "cot_steps": 2, "depends_on": ["T5"], "keywords": ["匯率", "幣別", "換算"]},
    {"id": "T5", "role": "worker", "goal": "換算金額", "input_schema": ["金額", "匯率"], "output_schema": ["本幣金額"],
     "est_tokens": 1200, "cot_steps": 3, "depends_on": ["T4"], "keywords": ["匯率", "幣別", "換算", "金額"]},
]}
d_rows, d_merges, d_crit, d_overall = check(normalize(demo))
print("【規則自我測試（離線，故意出錯的假計畫）】")
for tid, rule, res, why in d_rows:
    if res != "PASS":
        print(f"  {res:<4} {tid:<6} {rule:<8} {why}")
n_pass = sum(1 for r in d_rows if r[2] == "PASS")
print(f"  （另有 {n_pass} 項 PASS 未列出）")
print("  合併候選：", d_merges if d_merges else "無")
print("  整體判定：", d_overall)
print()

# 二、真實模型（只呼叫 1 次）
PROMPT = """你是 Agent Swarm 的 Planner。請把「審核一份跨國報價單（含價格、稅率、折扣、客戶信用額度、匯率）」拆成 4～8 個子任務。
每個子任務的格式：
{"id": "T1", "role": "planner|worker|monitor", "goal": "...", "input_schema": ["欄位"], "output_schema": ["欄位"], "est_tokens": 整數, "cot_steps": 整數, "depends_on": ["id"], "keywords": ["3～5 個詞"]}
輸出：{"tasks": [ ... ]}"""

md_path = os.path.join(OUT, "planner_granularity.md")
raw, err = None, None
print("呼叫 claude -p 中（最多 180 秒）……")
try:
    raw = ask_json(PROMPT)
except Exception as e:
    err = type(e).__name__ + ": " + str(e)
if err:
    print("模型呼叫失敗：", err)
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# 第 2 章練習 2：真實 Planner 拆任務\n\n呼叫失敗：" + err + "\n")
    print("已寫入", md_path)
    sys.exit(0)

tasks = normalize(raw)
print("【模型原始輸出】")
print(json.dumps(raw, ensure_ascii=False, indent=2)[:3000])
print()
print(f"共 {len(tasks)} 個子任務：")
for t in tasks:
    tid, role, tok, cot = t["id"], t["role"], t["est_tokens"], t["cot_steps"]
    deps = ",".join(t["depends_on"]) or "—"
    goal = t["goal"][:28]
    print(f"  {tid:<4} {role:<8} tokens={tok} cot={cot} 依賴={deps}  {goal}")
print()

# 三、程式規則逐項檢查
rows, merges, crit, overall = check(tasks)
print("【程式規則逐項檢查】")
for tid, rule, res, why in rows:
    print(f"  {res:<4} {tid:<6} {rule:<8} {why}")
print("合併候選：", merges if merges else "無")
if crit:
    path_s = " → ".join(crit[1])
    print(f"關鍵路徑：{path_s}  示意成功率 {crit[0]:.2%}")
print("整體判定：", overall)

# 四、心得（全部由程式規則產生）
def independent(word, other):
    out = []
    for t in tasks:
        text = t["goal"] + " " + " ".join(t["keywords"])
        tok, cot = t["est_tokens"], t["cot_steps"]
        if word in text and other not in text and t["role"] == "worker" and tok is not None and cot is not None and tok <= MAX_TOK and cot <= MAX_COT:
            out.append(t["id"])
    return out

credit, fx = independent("信用", "匯率"), independent("匯率", "信用")
n_mon = sum(1 for t in tasks if t["role"] == "monitor")
n_atomic_fail = sum(1 for r in rows if r[1] == "1 原子性" and r[2] == "FAIL")
if credit and fx:
    s1 = "模型有把信用額度（" + ",".join(credit) + "）和匯率（" + ",".join(fx) + "）拆成各自獨立的原子 worker 任務。"
else:
    s1 = "信用額度" + ("有" if credit else "沒有") + "獨立成原子任務、匯率" + ("有" if fx else "沒有") + "獨立成原子任務，沒拆開的部分要退回 Planner 重拆。"
if n_mon:
    s2 = "計畫裡有 " + str(n_mon) + " 個 monitor，但仍要確認它只觀察、不插手（WARN 列會標出可疑字眼）。"
else:
    s2 = "模型忘了 Monitor：整份計畫沒人盯哨，角色三原色直接 FAIL。"
s3 = "原子性 FAIL " + str(n_atomic_fail) + " 項、合併候選 " + str(len(merges)) + " 組。"
if crit:
    s4 = "關鍵路徑 " + " → ".join(crit[1]) + " 的示意成功率是 " + format(crit[0], ".2%") + "，鏈越長、推理越多，成功率越往下掉。"
else:
    s4 = "依賴圖有環或任務為空，算不出關鍵路徑。"
s5 = "以上全部由程式規則判定，模型的自我說明不算數；整體判定：" + overall + "。"

lines = ["# 第 2 章練習 2：真實 Planner 拆任務，用顆粒度閾值和角色規則驗收", "",
         "## A. 模型原始輸出", "", "~~~json", json.dumps(raw, ensure_ascii=False, indent=2), "~~~", "",
         "## B. 逐條檢查表（程式規則）", "", "| 任務 | 規則 | 結果 | 原因 |", "|---|---|---|---|"]
for tid, rule, res, why in rows:
    lines.append("| " + " | ".join([tid, rule, res, why]) + " |")
lines += ["", "## C. 合併候選（worker 關鍵詞 Jaccard ≥ 0.6）", ""]
lines += ["- " + a + " ＋ " + b + "（" + str(s) + "）" for a, b, s in merges] or ["- 無"]
lines += ["", "## D. 關鍵路徑與整體判定", "", "- " + s4, "- 整體判定：" + overall, "", "## E. 心得", "", s1 + s2 + s3 + s4 + s5]
with open(md_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print()
print("心得：", s1 + s2)
print("已寫入", md_path)'
   show "$P"; run "$P" ;;
8) banner "總結：Swarm 的價值是協作有規則"
   tip "先問自己三件事：誰下決策、誰搬資料、誰看異常？拆與合的閾值寫在哪裡、能不能被程式檢查？匯流排和黑板各有沒有流量上限和衝突解法？答不出來，就是 Swarm 還只有代理、沒有規則。"
   P='import os

OUT = "ch02/interactive"
points = [
    "角色三原色：Planner 拆局、Worker 收球（契約寫死、可拒單）、Monitor 盯哨只回流數據；沒有 Monitor 的流程就是空白區，一個走音讓 12 段鏈成功率從 88.6% 掉到 62.7%。",
    "生命週期：初始化→競價→鎖定→釋放，每段設檢查點；釋放階段沒有 TTL，崩潰的幽靈代理會一路佔滿資源池。",
    "顆粒度是槓桿：拆太粗錯誤疊乘到必錯、拆太細通訊稅吃掉平行度；tokens ≤ 8000、推理 ≤ 10 步是可被程式檢查的閾值，Jaccard ≥ 0.6 且合併後仍原子才合。",
    "Message Bus 要防廣播風暴：廣播投遞量隨 N² 成長，速率上限＋依能力訂閱把無關投遞降到 0；匯流排單點故障則要靠叢集、本地緩衝與直連備援。",
    "Blackboard 要防競寫：直接覆寫會悄悄遺失約三成更新，版本戳＋重試把遺失降到 0，真的寫不進去就退回 Planner，而不是丟掉。",
    "驗收模型的計畫要靠程式規則：原子性、契約、三原色、依賴圖、合併候選——Swarm 的價值不是代理夠多，而是協作有規則。",
]
print("【第 2 章重點】")
for i, p in enumerate(points, 1):
    print(f"  {i}. {p}")
print()
print("【本章產出的檔案】")
if os.path.isdir(OUT) and os.listdir(OUT):
    for name in sorted(os.listdir(OUT)):
        size = os.path.getsize(os.path.join(OUT, name))
        print(f"  - {OUT}/{name}（{size:,} bytes）")
else:
    print("  （還沒有檔案，請先跑第 5、6、7 步）")'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
