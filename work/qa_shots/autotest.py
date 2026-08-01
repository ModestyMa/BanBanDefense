"""伴伴 App 真机自动核验脚本（QA 用，只读不改码）
用法: python autotest.py <场景名>
依赖: hdc (DevEco SDK)
"""
import subprocess, json, time, sys, os

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
OUT = os.path.dirname(os.path.abspath(__file__))          # .../work/qa_shots
PROJ = os.path.dirname(os.path.dirname(OUT))              # .../HarmonyAPP
os.chdir(PROJ)  # hdc file recv 的本地路径按 cwd 解析，必须站在工程根


def sh(*args, timeout=40):
    r = subprocess.run([HDC] + list(args), capture_output=True, text=True,
                       encoding="utf-8", errors="ignore", timeout=timeout)
    return (r.stdout or "") + (r.stderr or "")


def tap(x, y, wait=1.2):
    sh("shell", "uinput", "-T", "-c", str(int(x)), str(int(y)))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, ms=400, wait=1.2):
    sh("shell", "uinput", "-T", "-m", str(x1), str(y1), str(x2), str(y2), str(ms))
    time.sleep(wait)


def back(wait=1.2):
    sh("shell", "uinput", "-K", "-d", "2", "-u", "2")
    time.sleep(wait)


def snap(tag):
    """截图 + dump 控件树，返回 (文本列表, 控件总数)"""
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


def show(tag, texts, cnt, skip_status=True):
    print(f"\n===== [{tag}] 控件总数={cnt} 带文本={len(texts)} =====")
    for typ, t, b in texts:
        # 过滤系统状态栏（y<200 且在顶部）
        if skip_status and b:
            try:
                y = int(b.split("][")[0].split(",")[1])
                if y < 200:
                    continue
            except Exception:
                pass
        print(f"  [{typ}] {t}  @{b}")


def alive():
    o = sh("shell", "aa", "dump", "-l")
    return "FOREGROUND" in o and PKG in o


def crashed():
    """判定应用是否已消失（崩溃或被杀）"""
    o = sh("shell", "ps", "-ef")
    return PKG not in o


if __name__ == "__main__":
    scene = sys.argv[1] if len(sys.argv) > 1 else "probe"
    texts, cnt = snap(scene)
    show(scene, texts, cnt)
    print("\n存活:", not crashed(), "| 前台:", alive())
