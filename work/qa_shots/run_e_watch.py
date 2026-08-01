"""T9 手表端 E 区核验：3 屏竖滑 + 概览 + 快记 + 倒数日
用法: python run_e_watch.py -t <sn>
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
    return list(map(int, m[:4])) if len(m) >= 4 else None


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


def show(tag, items):
    print(f"\n--- {tag} ---")
    if not items:
        print("  (无文本控件)")
    for typ, tx, b in items:
        p = parse_b(b)
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:9}] {tx[:30]:32} {xy}")


def crashed():
    lg = sh("shell", "aa", "dump", "-l")
    return PKG not in lg


def main():
    print("=" * 66)
    print(f"T9 手表 E 区核验  设备={SN}")
    print("=" * 66)
    # 屏幕尺寸
    w = sh("shell", "hidumper", "-s", "WindowManagerService", "-a", "-a")
    for line in w.splitlines():
        if "banban" in line or "WindowName" in line:
            print("  [win]", line.strip()[:150])

    print("\n[P-3] 冷启动")
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    r = sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG, "-m", "wearable")
    print("  start:", r.strip()[:120])
    time.sleep(9)
    print("  存活:", "❌ 已退出/崩溃" if crashed() else "✅ 运行中")

    it = snap("w_s1_overview")
    show("P-4/E-2/E-3 概览屏", it)
    joined1 = " ".join(x[1] for x in it)
    print("  隐私弹窗:", "⚠️ 出现（手表本不应弹）" if "同意" in joined1 and "隐私" in joined1 else "✅ 未弹（符合预期）")

    # 屏幕中心
    allp = [parse_b(b) for _, _, b in it if parse_b(b)]
    if allp:
        cx = (min(p[0] for p in allp) + max(p[2] for p in allp)) // 2
        cy = (min(p[1] for p in allp) + max(p[3] for p in allp)) // 2
    else:
        cx, cy = 233, 233
    print(f"  推定屏幕中心: ({cx},{cy})")

    print("\n[E-1a] 向上竖滑 → 快记屏")
    sh("shell", "uinput", "-T", "-m", str(cx), str(cy + 120), str(cx), str(cy - 120), "400")
    time.sleep(2.5)
    it2 = snap("w_s2_quickadd")
    show("E-4 快记屏", it2)

    print("\n[E-1b] 继续向上竖滑 → 倒数日屏")
    sh("shell", "uinput", "-T", "-m", str(cx), str(cy + 120), str(cx), str(cy - 120), "400")
    time.sleep(2.5)
    it3 = snap("w_s3_countdown")
    show("E-6 倒数日屏", it3)

    print("\n[E-1c] 反向下滑回退 x2")
    sh("shell", "uinput", "-T", "-m", str(cx), str(cy - 120), str(cx), str(cy + 120), "400")
    time.sleep(2.0)
    it4 = snap("w_back1")
    show("回退1", it4)
    sh("shell", "uinput", "-T", "-m", str(cx), str(cy - 120), str(cx), str(cy + 120), "400")
    time.sleep(2.0)
    it5 = snap("w_back2")
    show("回退2", it5)

    print("\n[存活]", "❌ 崩溃" if crashed() else "✅ OK")

    # 汇总
    j1 = " ".join(x[1] for x in it)
    j2 = " ".join(x[1] for x in it2)
    j3 = " ".join(x[1] for x in it3)
    j5 = " ".join(x[1] for x in it5)
    print("\n===== 快速判定 =====")
    print("  E-2 概览有数据:", "✅" if len(it) >= 2 else "❌ 空白")
    print("  E-3a 宠物区:", "✅" if any(k in j1 for k in ["Lv", "天", "🔥"]) else "❌ 未见")
    print("  E-3b 今日收支:", "✅" if any(k in j1 for k in ["支出", "收入", "结余", "¥", "余额"]) else "❌ 未见")
    print("  E-1a 滑到快记:", "✅" if j2 != j1 else "❌ 页面无变化")
    print("  E-1b 滑到倒数日:", "✅" if j3 != j2 else "❌ 页面无变化")
    print("  E-1c 回退成功:", "✅" if j5 == j1 or set(j5.split()) & set(j1.split()) else "❓ 需看图")


if __name__ == "__main__":
    main()
