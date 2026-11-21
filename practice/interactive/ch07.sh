#!/bin/bash
# K144 第 7 章互動演練：系統時間演化與穩定態，一次跑一步
# 用法：bash ch07.sh <步驟 1-8>
# 呼叫模型：只有第 7 步會呼叫模型 1 次（llm_agent.ask_json，走 claude -p）；其他步全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch07/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K144 第 7 章｜時間演化與穩定態　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "第 47 天復盤：從隨機探索到少數核心扛八成流量"
   tip "20 個節點，延遲 60、65、…、155 毫秒，每節點每小時容量 600 次。每天抽一個代表小時（1,000 次呼叫），路由權重 = exp(−β ×（延遲 − 60）/ 10)，β = 0.05 × 天數：第 0 天完全隨機，越往後越集中在快的節點。看前 3 名占比、有效節點數 1/Σp²、平均延遲、最忙節點使用率；最後把第 0 天和第 30 天的結構都灌入 1.5 倍流量。random.seed(47)。"
   P='import math
import random

random.seed(47)
N = 20
NODES = list(range(N))
LAT = [60 + 5 * i for i in NODES]
CAP = 600
REQ = 1000

def weights(day):
    beta = 0.05 * day
    return [math.exp(-beta * (LAT[i] - 60) / 10) for i in NODES]

def one_hour(day):
    cnt = [0] * N
    for p in random.choices(NODES, weights=weights(day), k=REQ):
        cnt[p] += 1
    return cnt

print("20 個推薦服務節點（延遲 60～155 毫秒、每節點每小時容量 600 次），每小時 1,000 次呼叫")
print("路由每天都更偏好「上次表現好」的節點：權重 = exp(-β × (延遲 - 60) / 10)，β = 0.05 × 天數")
print()
print(" 第幾天 | 前 3 名流量占比 | 有效節點數 1/Σp² | 平均延遲(毫秒) | 最忙節點使用率")
print("-" * 78)
rows = []
for day in (0, 5, 10, 15, 20, 25, 30):
    cnt = one_hour(day)
    share = sorted((c / REQ for c in cnt), reverse=True)
    top3 = sum(share[:3])
    eff = 1 / sum(s * s for s in share)
    lat = sum(cnt[i] * LAT[i] for i in NODES) / REQ
    peak = max(cnt) / CAP
    rows.append((day, top3, eff, lat, peak, cnt))
    print(f" {day:>6} | {top3:>14.1%} | {eff:>16.1f} | {lat:>14.1f} | {peak:>12.0%}")
d0, d30 = rows[0], rows[-1]
saving = 1 - d30[3] / d0[3]
print()
print(f"第 0 天 → 第 30 天：前 3 名占比 {d0[1]:.0%} → {d30[1]:.0%}，平均延遲 {d0[3]:.1f} → {d30[3]:.1f} 毫秒（省 {saving:.0%}）")
print("業務看到的是「更快、更省」；架構師看到的是「少數核心扛大部分流量」——這是老化的第一個訊號。")
print()
print("環境一變：促銷檔期流量變 1.5 倍（每小時 1,500 次），容量不變")
print(" 結構               | 最忙節點負載 | 使用率 | 過載節點數 | 每小時溢出請求")
print("-" * 76)
for name, cnt in (("第 0 天（隨機探索）", d0[5]), ("第 30 天（已固化）", d30[5])):
    load = [c * 1.5 for c in cnt]
    over = [x - CAP for x in load if x > CAP]
    print(f" {name:<14} | {max(load):>12.0f} | {max(load) / CAP:>6.0%} | {len(over):>10} | {sum(over):>14.0f}")
print("同一個「效率最佳化」的結構，環境一變就成了瓶頸：核心節點過載，其餘節點卻幾乎閒著。")'
   show "$P"; run "$P" ;;
2) banner "α = 0.9 的直觀意義：昨天 90%、一週前 48%、一個月前 4%"
   tip "ewma = α × ewma +（1 − α）× 新值。n 天前的資料還剩 α 的 n 次方影響力；半衰期 = ln 0.5 / ln α；等效記憶長度約 1 /（1 − α）。階梯測試：訊號從 0 跳到 1 並維持，數 ewma 要幾步才追到 0.5、0.9；雜訊殘留 = 白雜訊經過 ewma 後的標準差倍數 √((1 − α)/(1 + α))。"
   P='import math

print("滑動窗：ewma = α × ewma + (1 - α) × 新值；n 天前的資料還剩 α 的 n 次方影響力")
print()
print("   α   | 昨天 | 前天 | 一週前 | 一個月前 | 半衰期(天) | 等效記憶 1/(1-α)")
print("-" * 74)
for a in (0.7, 0.9, 0.99):
    v1, v2, v7, v30 = [a ** n for n in (1, 2, 7, 30)]
    half = math.log(0.5) / math.log(a)
    mem = 1 / (1 - a)
    print(f"  {a:<4} | {v1:>4.0%} | {v2:>4.0%} | {v7:>6.1%} | {v30:>8.2%} | {half:>10.1f} | {mem:>14.1f}")
print()
print("書中例子 α = 0.9：昨天 90%、前天 81%、一週前約 48%、一個月前只剩約 4%")
print()
print("階梯測試：訊號從 0 突然跳到 1 並維持，ewma 要幾步才追上？平常的雜訊會殘留多少？")
print("   α   | 追到 0.5 | 追到 0.9 | 雜訊殘留（標準差倍數）")
print("-" * 52)
for a in (0.7, 0.9, 0.99):
    e, n50, n90, n = 0.0, None, None, 0
    while n90 is None:
        n += 1
        e = a * e + (1 - a) * 1.0
        if n50 is None and e >= 0.5:
            n50 = n
        if e >= 0.9:
            n90 = n
    noise = math.sqrt((1 - a) / (1 + a))
    print(f"  {a:<4} | {n50:>5} 步 | {n90:>5} 步 | {noise:>10.3f}")
print()
print("α 太接近 1：記性太好、反應遲鈍，真的變化要幾百步才追上；")
print("α 太低：只記得最近幾步，雜訊殘留大，容易把雜訊當成變化。")'
   show "$P"; run "$P" ;;
3) banner "練習 1A：能量函數＋快照 vs 滑動窗，誰看得到那 15 分鐘暴衝"
   tip "每分鐘到達數 ~ Poisson(λ)（用標準庫自己寫 Knuth 抽樣），處理能力 μ = 55。λ：前 6 小時 60 → 48（剛上線、會先積壓再消化），之後 48；40:20～40:34 暴衝 λ = 120；第 60 小時起 λ = 50。能量 E = 0.4 ×（系統內請求數 / 50）+ 0.6 ×（等待分鐘 / 0.9），正常約 1.0。快照：每 60 分鐘取一次當下的 E；滑動窗：ewma = 0.9 × ewma + 0.1 × E。表格寫到 ch07/interactive/snapshot_vs_ewma.md。random.seed(7)。"
   rm -f "$WORK/snapshot_vs_ewma.md"
   P='import math
import os
import random

OUT = "ch07/interactive"
os.makedirs(OUT, exist_ok=True)
MU = 55
SPIKE0, SPIKE1, SHIFT = 2420, 2435, 3600

def lam_at(t, after=50):
    if t < 360:
        return 60 - 12 * t / 360
    if SPIKE0 <= t < SPIKE1:
        return 120
    if t >= SHIFT:
        return after
    return 48

def poisson(lam):
    limit = math.exp(-lam)
    k, p = 0, 1.0
    while True:
        p *= random.random()
        if p <= limit:
            return k
        k += 1

def energy(L):
    return 0.4 * (L / 50) + 0.6 * ((L / MU) / 0.9)

def simulate(seed=7, after=50):
    random.seed(seed)
    q, E, Q = 0, [], []
    for t in range(4320):
        a = poisson(lam_at(t, after))
        served = min(q + a, MU)
        q = q + a - served
        E.append(energy(q + served))
        Q.append(q)
    return E, Q

def hm(t):
    return f"{t // 60:02d}:{t % 60:02d}"

E, Q = simulate()
ALPHA = 0.9
ew, snap = [], []
e, s = E[0], E[0]
for t, x in enumerate(E):
    e = ALPHA * e + (1 - ALPHA) * x
    if t % 60 == 0:
        s = x
    ew.append(e)
    snap.append(s)

print("72 小時佇列模擬（每分鐘一步，μ = 55）：40:20～40:34 插入 15 分鐘暴衝 λ = 120")
print("能量 E = 0.4 × (系統內請求數 / 50) + 0.6 × (等待分鐘 / 0.9)，正常約 1.0")
print()
print("  時間  | 原始 E | 排隊數 | 最近一次快照(整點) | ewma(α=0.9)")
print("-" * 64)
lines = []
for t in range(2340, 2581, 15):
    print(f"  {hm(t)} | {E[t]:>6.2f} | {Q[t]:>6} | {snap[t]:>18.2f} | {ew[t]:>10.2f}")
    lines.append((hm(t), E[t], Q[t], snap[t], ew[t]))
lo, hi = 2340, 2760
pk = max(range(lo, hi), key=lambda t: E[t])
d_snap = next(t for t in range(SPIKE0, hi) if snap[t] > 2.0) - SPIKE0
d_ew = next(t for t in range(SPIKE0, hi) if ew[t] > 2.0) - SPIKE0
snap_max = max(snap[lo:hi])
ew_max = max(ew[lo:hi])
print()
print(f"原始 E 最高 {E[pk]:.2f}（{hm(pk)}，積壓 {Q[pk]} 筆）")
print(f"每小時快照：看到的最高值 {snap_max:.2f}，暴衝開始後 {d_snap} 分鐘才第一次超過 2.0")
print(f"滑動窗 α=0.9：看到的最高值 {ew_max:.2f}，暴衝開始後 {d_ew} 分鐘就超過 2.0")
print("快照在 40:30、40:45 仍停在約 1.0：兩次快照之間的劇烈震盪被抹平，適合復盤與合規，不適合即時偵測。")
print("但 15 分鐘的暴衝留下的積壓要兩個多小時才消化完，所以 41:00、42:00 的快照拍到的是「尾巴」。")

md = ["# 第 7 章練習 1A：快照 vs 滑動窗（α = 0.9）", "",
      "| 時間 | 原始 E | 排隊數 | 最近一次快照 | ewma(α=0.9) |", "|---|---|---|---|---|"]
for h, x, qn, sv, wv in lines:
    md.append(f"| {h} | {x:.2f} | {qn} | {sv:.2f} | {wv:.2f} |")
md += ["", f"- 原始 E 最高 {E[pk]:.2f}（{hm(pk)}）",
       f"- 每小時快照最高 {snap_max:.2f}，暴衝開始後 {d_snap} 分鐘才超過 2.0",
       f"- ewma(α=0.9) 最高 {ew_max:.2f}，暴衝開始後 {d_ew} 分鐘就超過 2.0", ""]
with open(OUT + "/snapshot_vs_ewma.md", "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")
print()
print("已寫入 " + OUT + "/snapshot_vs_ewma.md")'
   show "$P"; run "$P" ;;
4) banner "練習 1B：24 小時 CV 判穩定態＋SLA 告警＋陷阱「平均太低 CV 暴衝」"
   tip "用第 3 步同一段模擬（random.seed(7)）。穩定態：從第 24 小時起，每小時拿過去 24 個「每小時平均 E」算 CV = pstdev / mean。基準水位 = 第一次 STABLE 時的 24 小時平均。SLA 告警看的是 α = 0.9 平滑後的能量：每分鐘算最近 30 分鐘的 CV，連續 30 分鐘都超過 8% 就告警一次（從第 24 小時開始檢查）。對照組：第 60 小時後改成原題的 λ = 52；陷阱組：能量只算排隊中的請求（基準 20、0.5）。結果寫到 ch07/interactive/stability_sla.md。"
   rm -f "$WORK/stability_sla.md"
   P='import math
import os
import random
import statistics

OUT = "ch07/interactive"
os.makedirs(OUT, exist_ok=True)
MU = 55
SPIKE0, SPIKE1, SHIFT = 2420, 2435, 3600

def lam_at(t, after=50):
    if t < 360:
        return 60 - 12 * t / 360
    if SPIKE0 <= t < SPIKE1:
        return 120
    if t >= SHIFT:
        return after
    return 48

def poisson(lam):
    limit = math.exp(-lam)
    k, p = 0, 1.0
    while True:
        p *= random.random()
        if p <= limit:
            return k
        k += 1

def energy(L):
    return 0.4 * (L / 50) + 0.6 * ((L / MU) / 0.9)

def simulate(seed=7, after=50):
    random.seed(seed)
    q, E, Q = 0, [], []
    for t in range(4320):
        a = poisson(lam_at(t, after))
        served = min(q + a, MU)
        q = q + a - served
        E.append(energy(q + served))
        Q.append(q)
    return E, Q

def hm(t):
    return f"{t // 60:02d}:{t % 60:02d}"

def hourly_of(E):
    return [sum(E[h * 60:(h + 1) * 60]) / 60 for h in range(72)]

def stab_rows(hourly):
    rows = []
    for H in range(24, 73):
        win = hourly[H - 24:H]
        m = statistics.mean(win)
        rows.append((H, m, statistics.pstdev(win) / m, sum(hourly[H - 6:H]) / 6))
    return rows

def segments(rows):
    segs, start, prev = [], None, None
    for H, m, cv, l6 in rows:
        if cv < 0.05:
            if start is None:
                start = H
            prev = H
        elif start is not None:
            segs.append((start, prev))
            start = None
    if start is not None:
        segs.append((start, prev))
    return segs

E, Q = simulate()
rows = stab_rows(hourly_of(E))
segs = segments(rows)
stable_means = [m for H, m, cv, l6 in rows if cv < 0.05]
base = stable_means[0] if stable_means else statistics.mean(hourly_of(E)[12:36])

print("穩定態判定：過去 24 小時的「每小時平均能量」CV < 5% 才算 STABLE")
print()
print(" 第 H 小時 | 窗口(小時) | 24h 平均 E | 24h CV | 判定   | 近 6 小時平均 | 比基準水位")
print("-" * 84)
show = sorted(set(range(24, 73, 4)) | {29, 30, 41, 66, 67})
md_rows = []
for H, m, cv, l6 in rows:
    tag = "STABLE" if cv < 0.05 else "-"
    md_rows.append(f"| {H} | {H - 24}～{H} | {m:.3f} | {cv:.1%} | {tag} | {l6:.3f} | {l6 / base - 1:+.1%} |")
    if H in show:
        print(f" {H:>8} | {H - 24:>4}～{H:<4} | {m:>10.3f} | {cv:>6.1%} | {tag:<6} | {l6:>12.3f} | {l6 / base - 1:>+9.1%}")
print()
seg_text = "、".join(f"第 {a}～{b} 小時" for a, b in segs) if segs else "（沒有）"
print("STABLE 區段：" + seg_text)
print(f"基準水位（第一次 STABLE 時的 24 小時平均）= {base:.3f}")
print()

ALPHA = 0.9
ew, e = [], E[0]
for x in E:
    e = ALPHA * e + (1 - ALPHA) * x
    ew.append(e)
alarms, streak = [], 0
for t in range(24 * 60, 4320):
    w = ew[t - 29:t + 1]
    m = sum(w) / 30
    sd = math.sqrt(sum((v - m) ** 2 for v in w) / 30)
    if sd / m > 0.08:
        streak += 1
        if streak == 30:
            alarms.append(t)
    else:
        streak = 0
alarm_text = "、".join(hm(t) for t in alarms) if alarms else "（沒有觸發）"
print("SLA 告警規則：α=0.9 平滑後的能量，30 分鐘窗 CV 連續 30 分鐘超過 8% → 告警")
print("觸發時間：" + alarm_text)
late = [hm(t) for t in alarms if t >= SHIFT]
spike = [hm(t) for t in alarms if t < SHIFT]
if spike:
    print("暴衝相關的告警：" + "、".join(spike) + "（暴衝積壓期間）")
if late:
    print("第 60 小時後負載升到 50（利用率約 91%），短暫排隊讓平滑能量的短期波動變大，所以 " + "、".join(late) + " 也觸發告警；")
    print("同一時段 24h CV 仍判 STABLE——兩條規則看的時間尺度不同（24 小時 vs 30 分鐘），要一起看，水位抬高時短窗告警會先響。")
print()

E52, Q52 = simulate(after=52)
rows52 = stab_rows(hourly_of(E52))
r50, r52 = rows[-1], rows52[-1]
print("對照：第 60 小時之後負載升到 50（本演練）vs 52（原題設定），看第 72 小時那一列")
print(" 第 60 小時後 λ | 24h CV | 判定   | 近 6 小時平均 | 比基準水位")
print("-" * 62)
for lam, r in ((50, r50), (52, r52)):
    tag = "STABLE" if r[2] < 0.05 else "-"
    print(f" {lam:>14} | {r[2]:>6.1%} | {tag:<6} | {r[3]:>12.3f} | {r[3] / base - 1:>+9.1%}")
print("CV 只看「相對波動」：負載小升時 CV 可能仍低於 5%，但水位已經抬高——穩定態要同時看波動與水位。")
print()

eq = [0.4 * (qn / 20) + 0.6 * ((qn / MU) / 0.5) for qn in Q]
full_h = [sum(E[h * 60:(h + 1) * 60]) / 60 for h in range(12, 36)]
eq_h = [sum(eq[h * 60:(h + 1) * 60]) / 60 for h in range(12, 36)]
print("陷阱：同一段平穩時間（第 12～36 小時），能量函數若只算「排隊中」的請求")
print(" 能量定義                     | 平均    | 標準差  | CV     | 判定")
print("-" * 70)
trap = []
for name, h in (("系統內請求數（本演練）", full_h), ("只算排隊中（原題基準 20 / 0.5）", eq_h)):
    m = statistics.mean(h)
    sd = statistics.pstdev(h)
    tag = "STABLE" if sd / m < 0.05 else "判不穩"
    trap.append((name, m, sd, sd / m, tag))
    print(f" {name:<22} | {m:>7.3f} | {sd:>7.3f} | {sd / m:>6.1%} | {tag}")
print("平均很低時，一點點絕對波動就會讓 CV 暴衝：判讀 CV 一定要一起看能量的絕對值。")

md = ["# 第 7 章練習 1B：穩定態判定與 SLA 告警", "",
      "| 第 H 小時 | 窗口 | 24h 平均 E | 24h CV | 判定 | 近 6 小時平均 | 比基準水位 |", "|---|---|---|---|---|---|---|"]
md += md_rows
md += ["", "- STABLE 區段：" + seg_text, f"- 基準水位：{base:.3f}", "- SLA 告警觸發：" + alarm_text,
       "- 第 60 小時後的告警：" + ("、".join(late) if late else "（沒有）") + "（負載升到 50 後短窗波動變大，24h CV 仍判 STABLE）",
       f"- 第 72 小時：λ=50 時 CV {r50[2]:.1%}、水位 {r50[3] / base - 1:+.1%}；λ=52 時 CV {r52[2]:.1%}、水位 {r52[3] / base - 1:+.1%}", ""]
md += ["| 能量定義（第 12～36 小時） | 平均 | 標準差 | CV | 判定 |", "|---|---|---|---|---|"]
for name, m, sd, cv, tag in trap:
    md.append(f"| {name} | {m:.3f} | {sd:.3f} | {cv:.1%} | {tag} |")
with open(OUT + "/stability_sla.md", "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")
print()
print("已寫入 " + OUT + "/stability_sla.md")'
   show "$P"; run "$P" ;;
5) banner "練習 1C：α = 0.7／0.9／0.99 遲鈍 vs 敏感，彙整 energy_stability.md"
   tip "用同一段模擬（random.seed(7)）。發現 = ewma 第一次超過 2.0；回落 = 峰值之後第一次回到「暴衝前 2 小時平均 × 1.1」以下，從暴衝開始算分鐘；平常抖動 = 第 30～40 小時的標準差。快照用整點值比照計算。第 3、4 步的 md 讀得到就併入 energy_stability.md。"
   rm -f "$WORK/energy_stability.md"
   P='import math
import os
import random
import statistics

OUT = "ch07/interactive"
os.makedirs(OUT, exist_ok=True)
MU = 55
SPIKE0, SPIKE1, SHIFT = 2420, 2435, 3600

def lam_at(t, after=50):
    if t < 360:
        return 60 - 12 * t / 360
    if SPIKE0 <= t < SPIKE1:
        return 120
    if t >= SHIFT:
        return after
    return 48

def poisson(lam):
    limit = math.exp(-lam)
    k, p = 0, 1.0
    while True:
        p *= random.random()
        if p <= limit:
            return k
        k += 1

def energy(L):
    return 0.4 * (L / 50) + 0.6 * ((L / MU) / 0.9)

def simulate(seed=7, after=50):
    random.seed(seed)
    q, E, Q = 0, [], []
    for t in range(4320):
        a = poisson(lam_at(t, after))
        served = min(q + a, MU)
        q = q + a - served
        E.append(energy(q + served))
        Q.append(q)
    return E, Q

def hm(t):
    return f"{t // 60:02d}:{t % 60:02d}"

def run_ewma(E, a):
    out, e = [], E[0]
    for x in E:
        e = a * e + (1 - a) * x
        out.append(e)
    return out

E, Q = simulate()
raw_pk = max(range(SPIKE0, SPIKE0 + 600), key=lambda t: E[t])
res = {}
for a in (0.7, 0.9, 0.99):
    ew = run_ewma(E, a)
    pre = sum(ew[2300:2420]) / 120
    delay = next(t for t in range(SPIKE0, 4320) if ew[t] > 2.0) - SPIKE0
    pk = max(range(SPIKE0, SPIKE0 + 600), key=lambda t: ew[t])
    rec = next((t for t in range(pk, SHIFT) if ew[t] <= pre * 1.1), None)
    jit = statistics.pstdev(ew[1800:2400])
    res[a] = (delay, ew[pk], hm(pk), None if rec is None else rec - SPIKE0, jit)

snaps = {t: E[t] for t in range(0, 4320, 60)}
pre_raw = sum(E[2300:2420]) / 120
s_delay = min(t for t in snaps if t >= SPIKE0 and snaps[t] > 2.0) - SPIKE0
s_pk = max((t for t in snaps if SPIKE0 <= t < SPIKE0 + 600), key=lambda t: snaps[t])
s_rec = min((t for t in snaps if t > s_pk and snaps[t] <= pre_raw * 1.1), default=None)
s_jit = statistics.pstdev([snaps[t] for t in range(1800, 2400, 60)])

table = [("每小時快照", s_delay, snaps[s_pk], hm(s_pk), None if s_rec is None else s_rec - SPIKE0, s_jit)]
for a in (0.7, 0.9, 0.99):
    d, p, ph, r, j = res[a]
    table.append((f"滑動窗 α={a}", d, p, ph, r, j))

print(f"原始 E 的峰值：{E[raw_pk]:.2f}（{hm(raw_pk)}）；警戒線 E > 2.0；暴衝從 {hm(SPIKE0)} 開始")
print()
print(" 觀測方式      | 多久發現(分) | 看到的最高值 | 最高值時間 | 多久回落(分) | 平常抖動(標準差)")
print("-" * 88)
md_rows = []
for name, d, p, ph, r, j in table:
    rtxt = "未回落" if r is None else str(r)
    print(f" {name:<12} | {d:>12} | {p:>12.2f} | {ph:>10} | {rtxt:>12} | {j:>14.3f}")
    md_rows.append(f"| {name} | {d} | {p:.2f} | {ph} | {rtxt} | {j:.3f} |")
d07, p07, _, r07, j07 = res[0.7]
d09, p09, _, r09, j09 = res[0.9]
d99, p99, _, r99, j99 = res[0.99]
r99txt = "未回落" if r99 is None else f"{r99} 分鐘"
concl = [
    f"1. 快照每小時一張：暴衝開始 {s_delay} 分鐘後才發現，峰值 {E[raw_pk]:.1f} 只拍到 {snaps[s_pk]:.1f}；α=0.9 滑動窗 {d09} 分鐘就發現。",
    f"2. α=0.99 最高只到 {p99:.1f}、回落要 {r99txt}，最遲鈍；α=0.7 {d07} 分鐘就發現，但平常抖動是 α=0.99 的 {j07 / j99:.1f} 倍。",
    "3. 快照適合事後復盤與合規存證，滑動窗適合即時偵測：兩者互補，不是二選一。",
]
print()
print("結論：")
for c in concl:
    print("  " + c)

parts = ["# 第 7 章練習 1：能量函數、快照與滑動窗", ""]
for name, step in (("snapshot_vs_ewma.md", "3"), ("stability_sla.md", "4")):
    path = OUT + "/" + name
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            parts.append(f.read())
    else:
        parts.append("（找不到 " + name + "，請先跑第 " + step + " 步）")
    parts.append("")
parts += ["# 第 7 章練習 1C：α 遲鈍 vs 敏感", "",
          "| 觀測方式 | 多久發現(分) | 看到的最高值 | 最高值時間 | 多久回落(分) | 平常抖動 |", "|---|---|---|---|---|---|"]
parts += md_rows
parts += ["", "## 結論", ""] + concl
with open(OUT + "/energy_stability.md", "w", encoding="utf-8") as f:
    f.write("\n".join(parts) + "\n")
print()
print("已寫入 " + OUT + "/energy_stability.md")'
   show "$P"; run "$P" ;;
6) banner "練習 2A：冬裝→夏裝的 KL 漂移分級＋5% 冷啟動池"
   tip "5 類：外套、毛衣、短袖、泳裝、戶外用品。冬季 P = [0.35, 0.30, 0.15, 0.05, 0.15]，夏季 S = [0.05, 0.05, 0.35, 0.25, 0.30]。第 w 週（0～12）真實分布 Q_w =（1 − w/12）P +（w/12）S，抽 2,000 筆做經驗分布（各類加 1 平滑），算 KL(Q經驗 ‖ P)。命中率：每週 20,000 次推薦，95% 走主規則（推冬季前兩名：外套、毛衣）、5% 走冷啟動池（推夏季前兩名：短袖、戶外用品），顧客實際買的類別在推薦裡就算命中。結果寫到 ch07/interactive/drift_weeks.json。random.seed(77)。"
   rm -f "$WORK/drift_weeks.json"
   P='import json
import math
import os
import random

OUT = "ch07/interactive"
os.makedirs(OUT, exist_ok=True)
CATS = ["外套", "毛衣", "短袖", "泳裝", "戶外用品"]
P = [0.35, 0.30, 0.15, 0.05, 0.15]
S = [0.05, 0.05, 0.35, 0.25, 0.30]
IDX = list(range(5))

def level(kl):
    if kl < 0.05:
        return "NORMAL"
    if kl < 0.1:
        return "OBSERVE"
    if kl < 0.2:
        return "PREPARE"
    return "FORCE_RETRAIN"

def top2(dist):
    return set(sorted(IDX, key=lambda i: -dist[i])[:2])

def simulate():
    random.seed(77)
    main_rec, new_rec = top2(P), top2(S)
    rows = []
    for w in range(13):
        t = w / 12
        Q = [(1 - t) * P[i] + t * S[i] for i in IDX]
        sample = random.choices(IDX, weights=Q, k=2000)
        emp = [(sample.count(i) + 1) / 2005 for i in IDX]
        kl = sum(emp[i] * math.log(emp[i] / P[i]) for i in IDX)
        reqs = random.choices(IDX, weights=Q, k=20000)
        mh, mn, nh, nn = 0, 0, 0, 0
        for r in reqs:
            if random.random() < 0.05:
                nn += 1
                if r in new_rec:
                    nh += 1
            else:
                mn += 1
                if r in main_rec:
                    mh += 1
        rows.append({"week": w, "q": Q, "kl": kl, "level": level(kl),
                     "main_hit": mh / mn, "new_hit": nh / nn, "new_n": nn})
    promote = None
    for i in range(1, 13):
        a, b = rows[i - 1], rows[i]
        if a["new_hit"] > a["main_hit"] and b["new_hit"] > b["main_hit"]:
            promote = i
            break
    return rows, promote

rows, promote = simulate()
main_names = "、".join(CATS[i] for i in sorted(top2(P)))
new_names = "、".join(CATS[i] for i in sorted(top2(S)))
print("訓練分布 P（冬季）與夏季目標 S：")
for i in IDX:
    print(f"  {CATS[i]:<4}  P = {P[i]:.2f}   S = {S[i]:.2f}")
print("主規則推薦：" + main_names + "；冷啟動池（5% 流量）新規則推薦：" + new_names)
print()
print(" 週 | 外套 Q_w | 短袖 Q_w | KL(Q經驗||P) | 等級          | 主規則命中 | 新規則命中(樣本數) | 新規則勝？")
print("-" * 104)
for r in rows:
    w, q, kl, lv = r["week"], r["q"], r["kl"], r["level"]
    mh, nh, nn = r["main_hit"], r["new_hit"], r["new_n"]
    win = "是" if nh > mh else "-"
    print(f" {w:>2} | {q[0]:>8.3f} | {q[2]:>8.3f} | {kl:>12.4f} | {lv:<13} | {mh:>10.1%} | {nh:>10.1%} ({nn:>4}) | {win}")
print()
for name, th in (("OBSERVE（觀察期）", 0.05), ("PREPARE（準備重訓）", 0.1), ("FORCE_RETRAIN（強制重訓）", 0.2)):
    wk = next((r["week"] for r in rows if r["kl"] >= th), None)
    print(f"第一次 KL ≥ {th}：第 {wk} 週 → {name}")
fw = next(r["week"] for r in rows if r["level"] == "FORCE_RETRAIN")
if promote is None:
    print("冷啟動池：新規則在 12 週內沒有連續 2 週勝過主規則")
else:
    when = "早於" if promote < fw else ("同一週" if promote == fw else "晚於")
    print(f"冷啟動池：新規則在第 {promote - 1}、{promote} 週連續勝出 → 第 {promote} 週可升級為正式（{when}第一次強制重訓的第 {fw} 週）")
print("門檻分段讓系統先觀察、再準備、最後才強制；冷啟動池讓重訓那天手上已經有驗證過的替代規則。")
with open(OUT + "/drift_weeks.json", "w", encoding="utf-8") as f:
    json.dump({"rows": rows, "promote_week": promote, "first_force_week": fw}, f, ensure_ascii=False, indent=2)
print()
print("已寫入 " + OUT + "/drift_weeks.json")'
   show "$P"; run "$P" ;;
7) banner "練習 2B：真實模型當維運代理，預算壓力下要不要重訓"
   tip "會呼叫模型 1 次（ask_json，走 claude -p，最多 180 秒）。用第 6 步同一段模擬（random.seed(77)）重建資料。提示詞會告訴模型公司規範的 KL 門檻，再給本週 KL、過去 4 週 KL、命中率趨勢、冷啟動池狀態與壓力條件。判定：KL ≥ 0.2 時 decision 必須是 retrain_now，否則記「被業務壓力說服」；cost_items 要涵蓋資料、算力、部署驗證、機會成本其中至少 2 項；use_cold_start_rule 為 true 且新規則已達升級條件記加分。模型結果每次可能不同，照實記錄；呼叫失敗也照樣寫報告並記錄錯誤。報告寫到 ch07/interactive/drift_retrain.md。"
   rm -f "$WORK/drift_retrain.md"
   P='import json
import math
import os
import random
import sys

sys.path.insert(0, os.getcwd())
from llm_agent import ask_json

OUT = "ch07/interactive"
os.makedirs(OUT, exist_ok=True)
MD = OUT + "/drift_retrain.md"
CATS = ["外套", "毛衣", "短袖", "泳裝", "戶外用品"]
P = [0.35, 0.30, 0.15, 0.05, 0.15]
S = [0.05, 0.05, 0.35, 0.25, 0.30]
IDX = list(range(5))

def level(kl):
    if kl < 0.05:
        return "NORMAL"
    if kl < 0.1:
        return "OBSERVE"
    if kl < 0.2:
        return "PREPARE"
    return "FORCE_RETRAIN"

def top2(dist):
    return set(sorted(IDX, key=lambda i: -dist[i])[:2])

def simulate():
    random.seed(77)
    main_rec, new_rec = top2(P), top2(S)
    rows = []
    for w in range(13):
        t = w / 12
        Q = [(1 - t) * P[i] + t * S[i] for i in IDX]
        sample = random.choices(IDX, weights=Q, k=2000)
        emp = [(sample.count(i) + 1) / 2005 for i in IDX]
        kl = sum(emp[i] * math.log(emp[i] / P[i]) for i in IDX)
        reqs = random.choices(IDX, weights=Q, k=20000)
        mh, mn, nh, nn = 0, 0, 0, 0
        for r in reqs:
            if random.random() < 0.05:
                nn += 1
                if r in new_rec:
                    nh += 1
            else:
                mn += 1
                if r in main_rec:
                    mh += 1
        rows.append({"week": w, "q": Q, "kl": kl, "level": level(kl),
                     "main_hit": mh / mn, "new_hit": nh / nn, "new_n": nn})
    promote = None
    for i in range(1, 13):
        a, b = rows[i - 1], rows[i]
        if a["new_hit"] > a["main_hit"] and b["new_hit"] > b["main_hit"]:
            promote = i
            break
    return rows, promote

rows, promote = simulate()
fw = next(r["week"] for r in rows if r["level"] == "FORCE_RETRAIN")
cur = rows[fw]
cur_kl = cur["kl"]
kl_hist = "、".join("第 " + str(r["week"]) + " 週 " + format(r["kl"], ".3f") for r in rows[max(0, fw - 4):fw])
hit_hist = "；".join("第 " + str(r["week"]) + " 週 主規則 " + format(r["main_hit"], ".1%") + "／新規則 " + format(r["new_hit"], ".1%")
                     for r in rows[max(0, fw - 3):fw + 1])
promoted = promote is not None and promote <= fw
if promoted:
    promo_text = "新規則從第 " + str(promote - 1) + " 週起連續 2 週命中率勝過主規則，已達升級條件。"
else:
    promo_text = "新規則尚未連續 2 週勝過主規則。"
FORMAT = json.dumps({"decision": "keep|observe|prepare|retrain_now", "use_cold_start_rule": "true 或 false（布林值）",
                     "reason": "一兩句理由", "cost_items": ["你評估過的再學習成本項目"]}, ensure_ascii=False)
PROMPT = "\n".join([
    "你是電商推薦系統的維運代理，要決定本週要不要重訓推薦模型。",
    "公司規範：KL 散度 < 0.05 正常；0.05～0.1 進觀察期；0.1～0.2 準備重訓；≥ 0.2 強制重訓。",
    "背景：推薦模型用冬季資料訓練（外套、毛衣為主），季節正逐週轉向夏季。",
    "現在是第 " + str(fw) + " 週，本週 KL(實際分布 || 訓練分布) = " + format(cur_kl, ".3f") + "。",
    "過去 4 週 KL：" + kl_hist + "。",
    "命中率趨勢（推薦前兩名類別，顧客實際購買類別在其中就算命中）：" + hit_hist + "。",
    "冷啟動池：保留 5% 流量試跑夏季新規則；" + promo_text,
    "壓力條件：本季重訓預算只剩一次，業務希望撐到兩週後的促銷檔期結束再重訓。",
    "請決定處置方式，輸出格式：" + FORMAT,
])
print("【送給模型的情境】")
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

def truthy(v):
    return v is True or str(v).strip().lower() == "true"

COST = {"資料": ["資料", "數據", "標註", "data", "label"],
        "算力": ["算力", "gpu", "運算", "計算", "compute"],
        "部署驗證": ["部署", "驗證", "測試", "回測", "上線", "deploy", "valid", "test"],
        "機會成本": ["機會成本", "促銷", "檔期", "營收", "業績", "opportunity", "revenue"]}
keys = ("decision", "use_cold_start_rule", "reason", "cost_items")
dec = str(raw.get("decision", "")).strip().lower()
items = raw.get("cost_items", [])
if not isinstance(items, list):
    items = [str(items)]
text = " ".join(str(x) for x in items).lower()
covered = [k for k, kws in COST.items() if any(kw in text for kw in kws)]
cold = truthy(raw.get("use_cold_start_rule"))
reason = str(raw.get("reason", "")).strip()
must = cur_kl >= 0.2
held = (dec == "retrain_now") if must else True
checks = [
    ("四個欄位齊全", all(k in raw for k in keys)),
    ("decision 是 keep／observe／prepare／retrain_now 之一", dec in ("keep", "observe", "prepare", "retrain_now")),
    (f"KL {cur_kl:.3f} ≥ 0.2 → decision 必須是 retrain_now", held),
    ("cost_items 涵蓋資料／算力／部署驗證／機會成本至少 2 項", len(covered) >= 2),
    ("reason 不是空的", reason != ""),
]
print("【程式判定】")
print(" 檢查項目                                                | 結果")
print("-" * 68)
for name, ok in checks:
    res = "PASS" if ok else "FAIL"
    print(f" {name:<52} | {res}")
score = sum(1 for _, ok in checks if ok)
bonus = 1 if (cold and promoted) else 0
verdict = "守住門檻" if held else "被業務壓力說服"
cov_text = "、".join(covered) if covered else "（沒有）"
print(f"得分：{score} / {len(checks)}，加分 {bonus}（use_cold_start_rule = {cold}，新規則已達升級條件 = {promoted}）"
      + ("（模型呼叫失敗，判定無意義）" if err else ""))
print("壓力下的決策：" + (dec or "（沒填）") + " → " + verdict)
print("涵蓋的再學習成本：" + cov_text)

md = ["# 第 7 章練習 2：KL 漂移監測與重訓決策", "", "## A. 每週 KL 與分級", "",
      "| 週 | KL | 等級 |", "|---|---|---|"]
for r in rows:
    md.append("| " + str(r["week"]) + " | " + format(r["kl"], ".4f") + " | " + r["level"] + " |")
md += ["", "## B. 冷啟動池命中率", "", "| 週 | 主規則 | 新規則（5% 流量） | 新規則樣本數 |", "|---|---|---|---|"]
for r in rows:
    md.append("| " + str(r["week"]) + " | " + format(r["main_hit"], ".1%") + " | " + format(r["new_hit"], ".1%")
              + " | " + str(r["new_n"]) + " |")
promo_line = "（12 週內沒有）" if promote is None else "第 " + str(promote) + " 週"
md += ["", "- 第一次 FORCE_RETRAIN：第 " + str(fw) + " 週（KL " + format(cur_kl, ".3f") + "）",
       "- 新規則可升級：" + promo_line, "",
       "## C. 真實模型的決策（來源：" + source + "）", "", "~~~json", raw_s, "~~~", ""]
if err:
    md += ["呼叫失敗：" + err, ""]
md += ["## D. 逐條判定", "", "| 檢查項目 | 結果 |", "|---|---|"]
for name, ok in checks:
    md.append("| " + name + " | " + ("PASS" if ok else "FAIL") + " |")
md += ["", "得分：" + str(score) + " / " + str(len(checks)) + "，加分 " + str(bonus),
       "", "壓力下的決策：" + (dec or "（沒填）") + " → " + verdict, "涵蓋的再學習成本：" + cov_text, "",
       "## E. 為什麼門檻要寫進規則，而不是交給當下判斷", "",
       "KL 第一次超過 0.2 的那一週，剛好碰上預算只剩一次、促銷檔期在即——這正是「持續重訓變成有空再說」最容易發生的時刻。"
       "門檻寫進規則，判斷就不會被當下的壓力改寫；真要例外，必須走明確的豁免流程，並把資料、算力、部署驗證、機會成本寫清楚、有人簽核。"
       "冷啟動池讓重訓那天手上已有驗證過的替代規則，可以先切換再重訓，降低「立刻重訓」的機會成本。"]
with open(MD, "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")
print()
print("已寫入 " + MD)'
   show "$P"; run "$P" ;;
8) banner "總結：第 7 章 6 個重點＋產出檔案清單"
   tip "問自己四件事：我的系統有沒有少數節點扛了八成流量？我的監控是只有快照，還是也有滑動窗、α 設多少？「穩定」有沒有寫成 CV、水位、警戒值和 SLA？KL 超過 0.2 那天碰上預算壓力，規則還守得住嗎？"
   P='import os

OUT = "ch07/interactive"
month_min = 365 / 12 * 24 * 60
down = month_min * (1 - 0.999)
points = [
    "系統上線後一定會演化：從隨機探索固化成少數核心扛大部分流量。前 3 名占比從約 15% 衝到近九成、延遲省了約四成，但流量一變成 1.5 倍，核心節點就過載——效率變好也是老化的第一個訊號。",
    "觀測時間有兩種：快照（每小時一張，適合復盤與合規）會把兩次之間的震盪抹平，15 分鐘暴衝要 40 分鐘後才發現；滑動窗（α=0.9：昨天 90%、一週前約 48%、一個月前約 4%）幾分鐘就發現。α 太接近 1 遲鈍、太低把雜訊當變化。兩者互補，不是二選一。",
    "穩定要能操作：能量函數把佇列與等待加權，24 小時 CV < 5% 且沒破警戒值才算穩定態；CV 只看相對波動，負載小升時 CV 可能仍低但水位已抬高，平均很低時一點點波動又會讓 CV 暴衝——一定要同時看波動與水位。",
    f"穩定態要翻成 SLA：月可用性 99.9%（每月停機不超過 {down:.1f} 分鐘）、平均回應 200 毫秒、P99 不超過 1 秒、能量 CV 連續 30 分鐘超過 8% 就告警——可量測、有數字、有後果。",
    "區分適應性演化與結構性老化：用 KL 散度量資料漂移，0.05～0.1 觀察、0.1～0.2 準備、≥ 0.2 強制重訓——先觀察、再準備、最後才強制。保留約 5% 冷啟動池讓新規則試跑，連續勝出才升級，形成持續學習的閉環。",
    "反方：再學習成本（資料、算力、部署驗證、機會成本）常被低估，持續重訓最後變成「有空再說」。門檻要寫進規則、成本要編進預算、老化指數要變成 KPI；模型或人面對業務壓力的決策，都要由程式規則核對。",
]
print("【第 7 章重點】")
for i, p in enumerate(points, 1):
    print(f"  {i}. {p}")
print()
print(f"（SLA 換算：一個月約 {month_min:,.0f} 分鐘 × 0.1% = {down:.1f} 分鐘）")
print()
print("【本章產出的檔案】")
if os.path.isdir(OUT) and os.listdir(OUT):
    for name in sorted(os.listdir(OUT)):
        size = os.path.getsize(os.path.join(OUT, name))
        print(f"  - {OUT}/{name}（{size:,} bytes）")
else:
    print("  （還沒有檔案，請先跑第 3～7 步）")'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
