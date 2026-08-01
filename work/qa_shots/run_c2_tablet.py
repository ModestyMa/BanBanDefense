"""T8 平板 C-4/C-5：记账页 lg 布局 + 记一笔 + 报表分栏 + 倒数日新增 + 滚动
用法: python run_c2_tablet.py -t <sn>
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


def tap_b(p, wait=1.8):
    tap((p[0] + p[2]) // 2, (p[1] + p[3]) // 2, wait)


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


def show(tag, items, hide_nav=True):
    print(f"\n--- {tag} ---")
    if not items:
        print("  (空)")
    for typ, tx, b in items:
        p = parse_b(b)
        if hide_nav and p and p[2] < 300:
            continue
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:9}] {tx[:32]:34} {xy}")


def find(items, key, exact=False, xmax=None, xmin=None):
    for typ, tx, b in items:
        p = parse_b(b)
        if not p:
            continue
        if xmax is not None and p[0] > xmax:
            continue
        if xmin is not None and p[0] < xmin:
            continue
        if (tx == key) if exact else (key in tx):
            return (typ, tx, p)
    return None


def nav_to(tab):
    """点左侧导航（x<300）"""
    it = snap("_tmp_nav")
    t = find(it, tab, exact=True, xmax=300)
    if t:
        tap_b(t[2], 2.5)
        return True
    return False


def main():
    print("=" * 70)
    print(f"T8 平板 C-4/C-5  设备={SN}")
    print("=" * 70)

    # ---------- C-4a 进记账页 ----------
    print("\n[C-1c 修正] 点左侧导航「记账」")
    ok = nav_to("记账")
    print("  点击结果:", "已点" if ok else "❌ 未找到左侧记账 Tab")
    it = snap("c_tab_bill")
    show("记账页(lg)", it)
    joined = " ".join(x[1] for x in it)

    # 找加号 / 记一笔入口
    add = None
    for typ, tx, b in it:
        p = parse_b(b)
        if not p or p[0] < 300:
            continue
        if tx.strip() in ("+", "＋") or "记一笔" in tx or "添加" in tx:
            add = (typ, tx, p)
            break
    print("\n[C-4a] 记一笔入口:", add[1] if add else "❌ 未找到")
    if add:
        tap_b(add[2], 2.5)
        it2 = snap("c_bill_sheet")
        show("记账浮层", it2)

        # 输入金额：找输入框
        inp = None
        for typ, tx, b in it2:
            if typ in ("TextInput", "TextArea", "Search"):
                inp = parse_b(b)
                break
        if inp is None:
            # 用 dump 里 type 找不到就点浮层中部
            for typ, tx, b in it2:
                p = parse_b(b)
                if p and ("0.00" in tx or "金额" in tx or tx == "0"):
                    inp = p
                    break
        if inp:
            tap_b(inp, 1.5)
            sh("shell", "uinput", "-K", "-t", "38.50")
            time.sleep(1.5)
        else:
            print("  ⚠️ 未定位金额输入框，尝试直接输入")
            sh("shell", "uinput", "-K", "-t", "38.50")
            time.sleep(1.5)
        it3 = snap("c_bill_input")
        show("输入金额后", it3)

        save = find(it3, "保存", xmin=300) or find(it3, "确定", xmin=300) or find(it3, "完成", xmin=300)
        print("  保存按钮:", save[1] if save else "❌ 未找到")
        if save:
            tap_b(save[2], 3.0)
        it4 = snap("c_bill_after")
        show("保存后记账页", it4)
        j4 = " ".join(x[1] for x in it4)
        print("  C-4a 判定:", "✅ 出现 38.5 流水" if "38.5" in j4 or "38.50" in j4 else "❓ 未见 38.5，看图确认")

    # ---------- C-4b 报表分栏 ----------
    print("\n[C-4b] 进报表页")
    it5 = snap("_tmp_rep")
    rep = find(it5, "报表", xmin=300) or find(it5, "统计", xmin=300) or find(it5, "📊", xmin=300)
    if rep:
        tap_b(rep[2], 3.0)
        it6 = snap("c_report")
        show("报表页(lg 分栏)", it6)
        pts = [parse_b(b) for _, _, b in it6 if parse_b(b) and parse_b(b)[0] > 300]
        if pts:
            xs = sorted(set(p[0] for p in pts))
            print(f"  内容 x 分布: min={min(xs)} max={max(xs)}")
            mid = (min(xs) + max(xs)) / 2
            left = [p for p in pts if p[2] < mid]
            right = [p for p in pts if p[0] > mid]
            print(f"  左半区控件 {len(left)} 个 / 右半区 {len(right)} 个")
            print("  C-4b 判定:", "✅ 疑似左右分栏" if left and right else "❌ 未分栏(单列)")
    else:
        print("  ❌ 未找到报表入口")

    # ---------- C-5b 倒数日新增 ----------
    print("\n[C-5b] 倒数日新增")
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    nav_to("倒数日")
    itc = snap("c_cd_page")
    show("倒数日页", itc)
    plus = None
    for typ, tx, b in itc:
        p = parse_b(b)
        if p and p[0] > 300 and tx.strip() in ("+", "＋"):
            plus = p
            break
    print("  + 按钮:", plus if plus else "❌ 未找到")
    if plus:
        tap_b(plus, 2.5)
        itd = snap("c_cd_add")
        show("新增倒数日表单", itd)

    print("\n[存活]", "✅ OK" if PKG in sh("shell", "aa", "dump", "-l") else "❌ 崩溃")


if __name__ == "__main__":
    main()
