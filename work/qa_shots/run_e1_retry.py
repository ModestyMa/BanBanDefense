"""T9 手表 E-1 重试：加大滑动距离/速度适配圆屏
用法: python run_e1_retry.py -t <sn>
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
    time.sleep(0.8)
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
    for typ, tx, b in items:
        p = parse_b(b)
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:9}] {tx[:30]:32} {xy}")


def main():
    print("=" * 66)
    print(f"T9 手表 E-1 重试  设备={SN}")
    print("=" * 66)

    # 确认 App 在运行
    alive = PKG in sh("shell", "aa", "dump", "-l")
    if not alive:
        print("App 未运行，重新启动...")
        sh("shell", "aa", "force-stop", PKG)
        time.sleep(2)
        sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG, "-m", "wearable")
        time.sleep(9)

    it0 = snap("w_base")
    j0 = " ".join(x[1] for x in it0)
    print("基线文本:", j0[:80])

    cx, cy = 233, 233

    # 尝试多种滑动策略
    strategies = [
        ("长距慢速", cx, cy + 180, cx, cy - 180, 600),
        ("短距快速", cx, cy + 100, cx, cy - 100, 200),
        ("偏左滑", cx - 80, cy + 150, cx - 80, cy - 150, 500),
        ("偏右滑", cx + 80, cy + 150, cx + 80, cy - 150, 500),
        ("中心大滑", cx, cy + 200, cx, cy - 200, 800),
    ]

    for name, x1, y1, x2, y2, dur in strategies:
        print(f"\n--- 策略: {name} ({x1},{y1})→({x2},{y2}) dur={dur} ---")
        cmd = sh("shell", "uinput", "-T", "-m",
                 str(x1), str(y1), str(x2), str(y2), str(dur))
        time.sleep(3.0)
        it = snap(f"w_{name}")
        j = " ".join(x[1] for x in it)
        changed = j != j0
        print(f"  页面变化: {'✅ 是' if changed else '❌ 否'}")
        if changed:
            show(name, it)
            j0 = j
            break
        else:
            # 打印前几个控件看是否完全相同
            same = all(x[1] == y[1] for x, y in zip(it[:5], it0[:5]))
            print(f"  前5项相同: {same}")

    # 最终状态
    itf = snap("w_final")
    show("最终屏", itf)


if __name__ == "__main__":
    main()
