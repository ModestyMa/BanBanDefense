"""T5 手机 B 区剩余 4 项补验：B-4 倒数日增删改 / B-5 番茄完成态 / B-7 清除数据 / B-8 浮层关闭
用法: python run_b_remain.py -t <sn>
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
    print("=" * 70)
    print(f"T5 手机 B 区补验  设备={SN}")
    print("=" * 70)

    # 冷启动
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(9)

    it = snap("b_home")
    j = " ".join(x[1] for x in it)
    if "同意" in j:
        for typ, tx, b in it:
            if "同意" in tx:
                p = parse_b(b)
                if p: tap((p[0]+p[2])//2, (p[1]+p[3])//2)
                break
        time.sleep(3)
        it = snap("b_home2")

    # ========== B-4: 倒数日增删改 ==========
    print("\n===== B-4 倒数日增删改 =====")

    # 找底部 Tab 「倒数日」
    cd_tab = find(it, key="倒数日")
    if cd_tab:
        p = cd_tab[2]
        tap((p[0]+p[2])//2, (p[1]+p[3])//2, 2.5)
    else:
        print("  ⚠️ 未找到倒数日 Tab，尝试坐标点击底部导航区")
        tap(270, 1400, 2.5)

    it_cd = snap("b_cd_page")
    show("倒数日页", it_cd)

    # 找 + 按钮
    plus = find(it_cd, key="+", xmin=200)
    print(f"\n  B-4 新增: +按钮 {'✅' if plus else '❌'}")
    if plus:
        tap((plus[2][0]+plus[2][2])//2, (plus[2][1]+plus[2][3])//2, 2.5)
        it_form = snap("b_cd_form")
        show("新增表单", it_form)

        # 输入标题
        inp = find(it_form, typ="TextInput")
        if inp:
            tap((inp[2][0]+inp[2][2])//2, (inp[2][1]+inp[2][3])//2, 1.5)
            sh("shell", "uinput", "-K", "-t", "QA测试倒数日")
            time.sleep(1.5)

        save_btn = find(it_form, key="保存") or find(it_form, key="确定")
        if save_btn:
            tap((save_btn[2][0]+save_btn[2][2])//2, (save_btn[2][1]+save_btn[2][3])//2, 2.5)
            it_after = snap("b_cd_after_add")
            j_after = " ".join(x[1] for x in it_after)
            print(f"  B-4 新增结果: {'✅ 出现 QA测试' if 'QA测试' in j_after else '❌ 未见'}")
            show("新增后列表", it_after)

            # B-4 删除：长按或找删除入口
            # 先看列表里有没有刚加的条目
            qa_item = None
            for typ, tx, b in it_after:
                p = parse_b(b)
                if p and "QA测试" in tx:
                    qa_item = (typ, tx, p)
                    break
            if qa_item:
                print(f"  B-4 删除: 长按 '{qa_item[1]}'")
                tap((qa_item[2][0]+qa_item[2][2])//2, (qa_item[2][1]+qa_item[2][3])//2, 0.3)
                sh("shell", "uinput", "-T", "-l", "2000")
                time.sleep(2)
                it_del = snap("b_cd_after_del")
                j_del = " ".join(x[1] for x in it_del)
                print(f"  B-4 删除结果: {'✅ 已删除' if 'QA测试' not in j_del else '❌ 还在'}")

    # ========== B-5: 番茄完成态 ==========
    print("\n===== B-5 番茄完成态 =====")
    # 回首页点番茄 Tab
    it_tmp = snap("_tmp")
    tom_tab = find(it_tmp, key="番茄")
    if tom_tab:
        tap((tom_tab[2][0]+tom_tab[2][2])//2, (tom_tab[2][1]+tom_tab[2][3])//2, 2.5)
    it_tom = snap("b_tom_page")
    show("番茄页", it_tom)

    start_btn = find(it_tom, key="开始专注") or find(it_tom, key="开始")
    print(f"  开始按钮: {'✅' if start_btn else '❌'}")
    if start_btn:
        tap((start_btn[2][0]+start_btn[2][2])//2, (start_btn[2][1]+start_btn[2][3])//2, 2.5)
        # 等 3 秒看计时是否走动
        time.sleep(4)
        it_run = snap("b_tom_running")
        show("番茄运行中", it_run)
        j_run = " ".join(x[1] for x in it_run)
        has_timer = any(k in j_run for k in ["24:", "23:", "25:", "专注"])
        print(f"  计时运行: {'✅' if has_timer else '❌'}")

    # ========== B-7: 清除全部数据 ==========
    print("\n===== B-7 清除数据（观察） =====")
    # 这个通常需要进设置页，先看看有没有设置入口
    it_set = snap("_tmp_set")
    settings = find(it_set, key="设置") or find(it_set, key="⚙")
    print(f"  设置入口: {'✅' if settings else '❌ 未在当前页找到'}")
    if settings:
        tap((settings[2][0]+settings[2][2])//2, (settings[2][1]+settings[2][3])//2, 2.5)
        it_s = snap("b_settings")
        show("设置页", it_s)
        clear = find(it_s, key="清除") or find(it_s, key="删除") or find(it_s, key="重置") or find(it_s, key="清空")
        print(f"  清除数据选项: {clear[1] if clear else '❌ 未找到'}")

    # ========== B-8: 浮层关闭 ==========
    print("\n===== B-8 浮层关闭 =====")
    # 回记账页看浮层
    it_tmp2 = snap("_tmp_bill")
    bill_tab = find(it_tmp2, key="记账")
    if bill_tab:
        tap((bill_tab[2][0]+bill_tab[2][2])//2, (bill_tab[2][1]+bill_tab[2][3])//2, 2.5)
    it_bill = snap("b_bill_page")
    show("记账页(手机)", it_bill)

    # 检查是否有浮层/弹窗打开状态
    has_sheet = any(k in " ".join(x[1] for x in it_bill) for k in ["取消", "记一笔", "浮层"])
    print(f"  浮层状态: {'⚠️ 有浮层' if has_sheet else '✅ 无浮层(正常)'}")

    print("\n[存活]", "✅ OK" if PKG in sh("shell", "aa", "dump", "-l") else "❌ 崩溃")


if __name__ == "__main__":
    main()
