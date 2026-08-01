"""B-4 收键盘保存 + B-7 找设置"""
import time, subprocess, json, re, os

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
SN = "192.168.43.6:33359"
PKG = "com.modestyma.banban"
OUT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(OUT))
os.chdir(PROJ)


def sh(*args, timeout=60):
    cmd = [HDC, "-t", SN] + list(args)
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
    d = json.load(open(p, encoding="utf-8"))
    res = []

    def walk(n):
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        typ = a.get("type", "")
        if typ in ("TextInput", "Button", "Image") or t:
            res.append((typ, t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return res


# 1) 收键盘
print("=== 收键盘 ===")
sh("shell", "uitest", "uiInput", "click", "1180", "2800")
time.sleep(2)
it = snap("b4_nokbd")

# 2) 点保存
print("\n=== 点保存 ===")
save = None
for typ, tx, b in it:
    if "保存" in tx or "确定" in tx:
        save = parse_b(b)
        break
if save:
    cx, cy = (save[0] + save[2]) // 2, (save[1] + save[3]) // 2
    print(f"  保存: ({cx},{cy})")
    sh("shell", "uitest", "uiInput", "click", str(cx), str(cy))
    time.sleep(3)
    it2 = snap("b4_saved")
    j2 = " ".join(x[1] for x in it2)
    print(f"  B-4 结果: {'✅ QA出现' if 'QA' in j2 else '❌ 未见'}")
else:
    print("  ❌ 无保存按钮（可能已不在表单页）")
    it2 = it

# 3) 回首页找设置
print("\n=== B-7 首页设置 ===")
sh("shell", "uitest", "uiInput", "click", "180", "2680")
time.sleep(2)
it3 = snap("b7_home2")
print("  右上角区域:")
for typ, tx, b in it3:
    p = parse_b(b)
    if p and p[0] > 800 and p[1] < 350:
        print(f"    [{typ:10}] {tx[:20]:22} ({p[0]},{p[1]})-({p[2]},{p[3]})")
for typ, tx, b in it3:
    if "\u2699" in tx or "设置" in tx:
        p = parse_b(b)
        print(f"  设置: [{typ}] {tx} bounds={p}")

print("\n[存活]", "OK" if PKG in sh("shell", "aa", "dump", "-l") else "CRASH")
