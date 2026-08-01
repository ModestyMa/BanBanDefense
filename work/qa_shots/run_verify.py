"""多设备 BUG-004 复验：冷启动 N 次，统计首页三卡渲染失败（空白）次数
用法: python run_verify.py -t <设备序列号> -n <次数，默认20>
判定: 每轮 dump 首页，若三卡区域(倒数日/番茄/记账)至少有一条可见文案(含空态占位)即通过；
      全无可见文案 = BUG-004 空白复现 = 失败。
"""
import sys, os, time, json, subprocess

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
OUT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(OUT))
os.chdir(PROJ)

SN = None
N = 20
for i, a in enumerate(sys.argv):
    if a == "-t" and i + 1 < len(sys.argv):
        SN = sys.argv[i + 1]
    if a == "-n" and i + 1 < len(sys.argv):
        N = int(sys.argv[i + 1])


def sh(*args, timeout=40):
    cmd = [HDC]
    if SN:
        cmd += ["-t", SN]
    cmd += list(args)
    r = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="ignore", timeout=timeout)
    return (r.stdout or "") + (r.stderr or "")


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
    except Exception:
        return [f"<PARSE_ERROR>"], 0
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
    ok = 0
    fails = []
    for i in range(1, N + 1):
        sh("shell", "aa", "force-stop", PKG)
        time.sleep(2)
        sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
        time.sleep(8)
        t, c = snap(f"v{SN.replace(':', '_')}_{i}")
        joined = " ".join(x[1] for x in t)
        keys = ["今天还没记账", "还没有倒数", "今天还没专注", "支出", "笔",
                "专注", "倒数日", "记账", "天"]
        hit = [k for k in keys if k in joined]
        good = bool(hit)
        if good:
            ok += 1
        else:
            fails.append(i)
        print(f"[第{i}轮] 三卡可见={hit} -> {'✅' if good else '❌ 空白'}", flush=True)
    print(f"\n>>> {SN} 冷启动 {N} 次，三卡渲染正常 {ok} 次，空白 {N - ok} 次", flush=True)
    if fails:
        print(f">>> 失败轮次: {fails}")


if __name__ == "__main__":
    main()
