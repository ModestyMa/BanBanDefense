"""T5 手机 B-4 修正：精确点击 + 按钮（用 uitest uiInput click）+ B-7 设置页
用法: python run_b4_fix.py -t <sn>
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


def tap(x, y, wait=1.5):
    sh("shell", "uinput", "-T", "-c", str(int(x)), str(int(y)))
    time.sleep(wait)


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
        typ = a.get("type", "")
        if typ in ("TextInput", "Button") or t:
            res.append((typ, t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return res


def show(tag, items, skip_top=150):
    print(f"\n--- {tag} ---")
    for typ, tx, b in items:
        p = parse_b(b)
        if p and p[1] < skip_top:
            continue
        xy = f"({p[0]},{p[1]})-({p[2]},{p[3]})" if p else "?"
        print(f"  [{typ:10}] {tx[:28]:30} {xy}")


def find(items, key=None, typ=None, xmin=0):
    for t, tx, b in items:
        p = parse_b(b)
        if not p or p[0] < xmin:
            continue
        if typ and t == typ:
            return (t, tx, p)
        if key and key in tx:
            return (t, tx, p)
    return None


def main():
    # ====== B-4 修正：用 uitest click 点 + 按钮 ======
    print("=" * 66)
    print("B-4 修正 + B-7 设置页")
    print("=" * 66)

    # 先确保在倒数日页
    it = snap("_tmp")
    cd_tab = find(it, key="倒数日")
    if cd_tab:
        tap((cd_tab[2][0]+cd_tab[2][2])//2, (cd_tab[2][1]+cd_tab[2][3])//2, 2.5)
    time.sleep(1)
    it_cd = snap("b4_cd")

    plus_btn = find(it_cd, typ="Button", xmin=200)
    print(f"\n[B-4] + Button: bounds={plus_btn[2]}" if plus_btn else "\n[B-4] ❌ 无 Button")

    if plus_btn:
        p = plus_btn[2]
        cx, cy = (p[0]+p[2])//2, (p[1]+p[3])//2
        print(f"  用 uitest click ({cx},{cy})")
        sh("shell", "uitest", "uiInput", "click", str(cx), str(cy))
        time.sleep(3)
        it_form = snap("b4_form")
        j_form = " ".join(x[1] for x in it_form)
        has_form = any(k in j_form for k in ["新建", "标题", "目标日期", "保存"])
        print(f"  表单弹出: {'✅' if has_form else '❌'}")
        show("新增表单", it_form)

        if has_form:
            # 输入标题
            inp = find(it_form, typ="TextInput")
            if inp:
                tap((inp[2][0]+inp[2][2])//2, (inp[2][1]+inp[2][3])//2, 1.5)
                sh("shell", "uinput", "-K", "-t", "QA测试")
                time.sleep(1.5)
            save = find(it_form, key="保存") or find(it_form, key="确定")
            if save:
                tap((save[2][0]+save[2][2])//2, (save[2][1]+save[2][3])//2, 2.5)
                it_after = snap("b4_after")
                j_after = " ".join(x[1] for x in it_after)
                print(f"\n  B-4 新增: {'✅ QA测试 出现' if 'QA测试' in j_after else '❌ 未见'}")

                # 删除
                qa = None
                for t, tx, b in it_after:
                    if "QA测试" in tx:
                        qa = parse_b(b)
                        break
                if qa:
                    print(f"  B-4 删除: longPress ({(qa[0]+qa[2])//2}, {(qa[1]+qa[3])//2})")
                    sh("shell", "uitest", "uiInput", "longClick",
                       str((qa[0]+qa[2])//2), str((qa[1]+qa[3])//2))
                    time.sleep(2)
                    it_del = snap("b4_del")
                    j_del = " ".join(x[1] for x in it_del)
                    print(f"  B-4 删除: {'✅ 已删' if 'QA测试' not in j_del else '❌ 还在'}")

    # ====== B-7: 回首页找设置 ======
    print("\n===== B-7 清除数据 =====")
    it_home = snap("b7_home")
    settings = find(it_home, key="⚙") or find(it_home, key="设置")
    # 也检查右上角区域
    if not settings:
        for typ, tx, b in it_home:
            p = parse_b(b)
            if p and p[0] > 900 and p[1] < 300 and p[1] > 100:
                settings = (typ, tx, p)
                break
    print(f"  设置入口: {settings[1] if settings else '❌ 未找到'} bounds={settings[2] if settings else ''}")
    if settings:
        tap((settings[2][0]+settings[2][2])//2, (settings[2][1]+settings[2][3])//2, 2.5)
        it_s = snap("b7_settings")
        show("设置页", it_s)
        clear_opt = find(it_s, key="清除") or find(it_s, key="删除") or find(it_s, key="重置") or find(it_s, key="清空") or find(it_s, key="数据")
        print(f"  清除选项: {clear_opt[1] if clear_opt else '❌ 未找到'}")

    print("\n[存活]", "✅ OK" if PKG in sh("shell", "aa", "dump", "-l") else "❌ 崩溃")


if __name__ == "__main__":
    main()
