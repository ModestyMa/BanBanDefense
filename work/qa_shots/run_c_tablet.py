"""T8 平板端 C 区核验：lg 断点布局判定
用法: python run_c_tablet.py -t <sn>
输出：导航形态(左侧/底部)、三卡排布(横排/竖排)、内容限宽、各 Tab 切换
"""
import sys, os, time, json, re, subprocess

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
OUT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(OUT))
os.chdir(PROJ)

SN = None
for i, a in enumerate(sys.argv):
    if a == "-t" and i + 1 < len(sys.argv):
        SN = sys.argv[i + 1]


def sh(*args, timeout=60):
    cmd = [HDC]
    if SN:
        cmd += ["-t", SN]
    cmd += list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="ignore", timeout=timeout)
        return (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return f"<ERR {e}>"


def parse_b(b):
    m = re.findall(r"-?\d+", b or "")
    if len(m) >= 4:
        return list(map(int, m[:4]))
    return None


def tap_b(b):
    p = parse_b(b)
    if p:
        sh("shell", "uinput", "-T", "-c", str((p[0] + p[2]) // 2), str((p[1] + p[3]) // 2))
        time.sleep(1.5)
        return True
    return False


def snap(tag):
    sh("shell", "snapshot_display", "-f", f"/data/local/tmp/{tag}.jpeg")
    sh("file", "recv", f"/data/local/tmp/{tag}.jpeg", f"work/qa_shots/{tag}.jpeg")
    sh("shell", "uitest", "dumpLayout", "-p", f"/data/local/tmp/{tag}.json")
    time.sleep(1.0)
    sh("file", "recv", f"/data/local/tmp/{tag}.json", f"work/qa_shots/{tag}.json")
    p = f"work/qa_shots/{tag}.json"
    if not os.path.exists(p):
        return []
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        return [("PARSE_ERR", str(e), "")]
    res = []

    def walk(n):
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if t:
            res.append((a.get("type", ""), t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return res


def show(tag, items, skip_top=120):
    print(f"\n--- {tag} ---")
    for typ, tx, b in items:
        p = parse_b(b)
        if p and p[1] < skip_top:
            continue
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:9}] {tx[:34]:36} {xy}")


TABS = ["首页", "倒数日", "番茄", "记账"]


def main():
    print("=" * 70)
    print(f"T8 平板 C 区核验  设备={SN}")
    print("=" * 70)
    print(sh("shell", "hidumper", "-s", "WindowManagerService", "-a", "-a").split("banban")[0][:0] or "", end="")

    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(10)

    items = snap("c_home")
    joined = " ".join(x[1] for x in items)
    if "同意" in joined:
        for typ, tx, b in items:
            if "同意" in tx:
                tap_b(b)
                break
        time.sleep(3)
        items = snap("c_home")

    show("C 首页(lg)", items)

    # --- C-1: 导航形态 ---
    tabpos = {}
    for typ, tx, b in items:
        for t in TABS:
            if tx == t and t not in tabpos:
                p = parse_b(b)
                if p:
                    tabpos[t] = p
    print("\n[C-1 导航形态判定]")
    print("  Tab 命中:", list(tabpos.keys()))
    verdict_nav = "?"
    if len(tabpos) >= 3:
        xs = [v[0] for v in tabpos.values()]
        ys = [v[1] for v in tabpos.values()]
        if max(ys) - min(ys) > 200 and max(xs) - min(xs) < 300:
            verdict_nav = "左侧竖排 (lg 正确)"
        elif max(xs) - min(xs) > 400 and max(ys) - min(ys) < 200:
            verdict_nav = "底部横排 (sm 形态)"
        else:
            verdict_nav = f"不明 xs={xs} ys={ys}"
        for k, v in tabpos.items():
            print(f"    {k}: x={v[0]} y={v[1]}")
    print("  → 判定:", verdict_nav)

    # --- C-3: 三卡排布 ---
    print("\n[C-3 三卡排布判定]")
    card_keys = {"倒数日卡": ["还没有倒数", "倒数日", "天后"],
                 "番茄卡": ["还没专注", "今日专注", "专注", "个番茄"],
                 "记账卡": ["还没记账", "支出", "收入", "结余"]}
    found = {}
    for name, keys in card_keys.items():
        for typ, tx, b in items:
            p = parse_b(b)
            if not p or p[1] < 150:
                continue
            if any(k in tx for k in keys) and name not in found:
                found[name] = (tx, p)
    for k, v in found.items():
        print(f"    {k}: '{v[0][:20]}' y={v[1][1]} x={v[1][0]}")
    verdict_card = "?"
    if len(found) >= 3:
        ys = [v[1][1] for v in found.values()]
        xs = [v[1][0] for v in found.values()]
        if max(ys) - min(ys) < 180 and max(xs) - min(xs) > 300:
            verdict_card = "横排一行 (lg 正确)"
        elif max(ys) - min(ys) > 200:
            verdict_card = "竖排 (sm 形态)"
        else:
            verdict_card = f"不明 ys={ys} xs={xs}"
    print("  → 判定:", verdict_card)

    # --- C-2: 内容限宽 ---
    print("\n[C-2 内容居中限宽]")
    allp = [parse_b(b) for _, _, b in items if parse_b(b)]
    body = [p for p in allp if p[1] > 150 and p[3] - p[1] < 600]
    if body:
        left = min(p[0] for p in body)
        right = max(p[2] for p in body)
        print(f"    内容横向范围: {left} ~ {right} (宽 {right-left}px)")
    print("\n[C-1c 逐 Tab 切换]")
    for t in TABS[1:]:
        if t in tabpos:
            p = tabpos[t]
            sh("shell", "uinput", "-T", "-c", (p[0] + p[2]) // 2, (p[1] + p[3]) // 2) if False else None
            sh("shell", "uinput", "-T", "-c", str((p[0] + p[2]) // 2), str((p[1] + p[3]) // 2))
            time.sleep(2.5)
            it = snap("c_tab_" + t)
            show("Tab=" + t, it)
        else:
            print(f"  {t}: 未找到 Tab 控件")

    alive = sh("shell", "aa", "dump", "-l")
    print("\n[存活]", "OK" if PKG in alive else "❌ 进程不在")


if __name__ == "__main__":
    main()
