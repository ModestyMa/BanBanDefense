"""T8 平板 C-4a 修正版：收集所有控件类型 + 正确输入金额
用法: python run_c3_bill.py -t <sn>
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


def tap(x, y, wait=1.8):
    sh("shell", "uinput", "-T", "-c", str(int(x)), str(int(y)))
    time.sleep(wait)


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
        typ = a.get("type", "")
        # 收集所有交互控件（含空文本）
        if typ in ("TextInput", "TextArea", "Search", "Button", "Toggle", "Slider",
                    "Checkbox", "Radio", "Stepper") or t:
            res.append((typ, t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return res


def show(tag, items, hide_nav=True):
    print(f"\n--- {tag} ---")
    if not items:
        print("  (空)")
    for typ, tx, b in items:
        p = parse_b(b)
        if hide_nav and p and p[2] < 300:
            continue
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:12}] {tx[:24]:26} {xy}")


def find(items, key=None, typ=None, xmin=300):
    """按 type 或 text 查找，限 x>=xmin"""
    for t, tx, b in items:
        p = parse_b(b)
        if not p or p[0] < xmin:
            continue
        if typ and t == typ:
            return (t, tx, p)
        if key and key in tx:
            return (t, tx, p)
    return None


def nav_to(tab):
    it = snap("_tmp_nav")
    for typ, tx, b in it:
        p = parse_b(b)
        if p and p[2] < 300 and tx == tab:
            tap((p[0] + p[2]) // 2, (p[1] + p[3]) // 2, 2.5)
            return True
    return False


def main():
    print("=" * 70)
    print(f"T8 平板 C-4a 记账  设备={SN}")
    print("=" * 70)

    # 冷启动到首页
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(9)

    # 点左侧导航「记账」
    print("\n→ 进记账页")
    nav_to("记账")
    time.sleep(1)
    it = snap("c_bill_page")
    show("记账页(全控件)", it)

    # 找 TextInput（金额输入框）
    inp = find(it, typ="TextInput")
    print(f"\n[C-4a] 金额输入框: {inp[1]} bounds={inp[2]}" if inp else "\n❌ 未找到 TextInput")

    # 也尝试找 ¥ 符号附近区域
    yen = find(it, key="¥")
    print(f"  ¥ 符号: {yen[1]} bounds={yen[2]}" if yen else "  未找到 ¥")

    if inp:
        p = inp[2]
        tap((p[0] + p[2]) // 2, (p[1] + p[3]) // 2, 1.5)
        # 用 uinput -K 键盘模式输入金额
        sh("shell", "uinput", "-K", "-t", "38.50")
        time.sleep(1.5)
        it2 = snap("c_after_input")
        show("输入后", it2)
    elif yen:
        p = yen[2]
        # 点击 ¥ 右侧区域（通常是输入区）
        tap((p[2] + 100), (p[1] + p[3]) // 2, 1.5)
        sh("shell", "uinput", "-K", "-t", "38.50")
        time.sleep(1.5)
        it2 = snap("c_after_input")
        show("输入后", it2)
    else:
        # 兜底：直接在表单中部点击然后键盘输入
        print("  ⚠️ 兜底：点表单中部 + 键盘输入")
        tap(1447, 310, 1.5)
        sh("shell", "uinput", "-K", "-t", "38.50")
        time.sleep(1.5)
        it2 = snap("c_after_input")
        show("输入后(兜底)", it2)

    # 找保存按钮并点击
    save = find(it2, key="保存") or find(it2, key="确定")
    print(f"\n  保存: {save[1]}" if save else "  ❌ 无保存按钮")
    if save:
        tap((save[2][0] + save[2][2]) // 2, (save[2][1] + save[2][3]) // 2, 3.0)
        it3 = snap("c_after_save")
        show("保存后", it3)
        j3 = " ".join(x[1] for x in it3)
        print(f"\n  C-4a 判定: {'✅ 出现 38.5 流水' if '38.5' in j3 or '38.50' in j3 else '❓ 看图确认'}")

    # C-4b 报表分栏
    print("\n[C-4b] 进报表页")
    rep = find(it3 if 'it3' in dir() else it2, key="报表") or find(it3 if 'it3' in dir() else it2, key="统计")
    if rep:
        tap((rep[2][0] + rep[2][2]) // 2, (rep[2][1] + rep[2][3]) // 2, 3.0)
        itr = snap("c_report_lg")
        show("报表页(lg)", itr)
        pts = [parse_b(b) for _, _, b in itr if parse_b(b) and parse_b(b)[0] > 300]
        if pts:
            xs = sorted(set(p[0] for p in pts))
            mid = (min(xs) + max(xs)) / 2
            left = len([p for p in pts if p[2] < mid])
            right = len([p for p in pts if p[0] > mid])
            print(f"  x范围 [{min(xs)}, {max(xs)}] 中点={mid:.0f} 左{left}右{right}")

    print("\n[存活]", "✅ OK" if PKG in sh("shell", "aa", "dump", "-l") else "❌ 崩溃")


if __name__ == "__main__":
    main()
