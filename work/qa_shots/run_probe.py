"""多设备探活：冷启动 + 自动同意隐私弹窗 + 判定首页三卡是否渲染
用法: python run_probe.py -t <设备序列号>
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


def sh(*args, timeout=40):
    cmd = [HDC]
    if SN:
        cmd += ["-t", SN]
    cmd += list(args)
    r = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="ignore", timeout=timeout)
    return (r.stdout or "") + (r.stderr or "")


def tap_bounds(bounds):
    m = re.findall(r"\d+", bounds)
    if len(m) >= 4:
        x1, y1, x2, y2 = map(int, m[:4])
        x, y = (x1 + x2) // 2, (y1 + y2) // 2
        sh("shell", "uinput", "-T", "-c", str(x), str(y))
        time.sleep(1.2)


def snap(tag):
    sh("shell", "snapshot_display", "-f", f"/data/local/tmp/{tag}.jpeg")
    sh("file", "recv", f"/data/local/tmp/{tag}.jpeg", f"work/qa_shots/{tag}.jpeg")
    sh("shell", "uitest", "dumpLayout", "-p", f"/data/local/tmp/{tag}.json")
    time.sleep(0.8)
    sh("file", "recv", f"/data/local/tmp/{tag}.json", f"work/qa_shots/{tag}.json")
    p = f"work/qa_shots/{tag}.json"
    if not os.path.exists(p):
        return [], 0
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        return [f"<PARSE_ERROR {e}>"], 0
    texts, cnt = [], 0

    def walk(n):
        nonlocal cnt
        cnt += 1
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if t:
            texts.append((a.get("type", ""), t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return texts, cnt


def main():
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(9)
    tag = "probe_" + (SN or "dev").replace(":", "_")
    t, c = snap(tag)
    joined = " ".join(x[1] for x in t)
    # 隐私弹窗自动同意
    if "同意" in joined:
        for typ, tx, b in t:
            if "同意" in tx:
                tap_bounds(b)
                break
        time.sleep(3)
        t, c = snap(tag + "_after")
        joined = " ".join(x[1] for x in t)

    print(f"=== PROBE {SN} 控件总数={c} ===")
    for typ, tx, b in t:
        try:
            y = int(b.split("][")[0].split(",")[1])
            if y < 200:
                continue
        except Exception:
            pass
        print(f"  [{typ}] {tx}")
    keys = ["今天还没记账", "支出", "笔", "还没有倒数", "今日专注", "专注",
            "倒数日", "天", "记账", "宠物"]
    hit = [k for k in keys if k in joined]
    print("三卡/宠物可见文案:", hit)
    print("判定:", "✅ 三卡渲染正常" if hit else "❌ 首页无可见文案(BUG-004?)")
    print("存活:", "FOREGROUND" in sh("shell", "aa", "dump", "-l") and PKG in sh("shell", "aa", "dump", "-l"))


if __name__ == "__main__":
    main()
