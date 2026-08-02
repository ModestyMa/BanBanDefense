#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""T9 E-4/E-5 终验: 手表快记保存 -> 概览今日支出增加 + 宠物打卡联动"""
import sys, os, time, json, re, subprocess

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
PROJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(PROJ)
SN = "192.168.43.202:34021"
for i, a in enumerate(sys.argv):
    if a == "-t" and i + 1 < len(sys.argv):
        SN = sys.argv[i + 1]

# 手表 IME 数字键坐标（466x466 圆屏，已在 v7 中标定）
KEYS = {'1': (75, 218), '2': (168, 218), '3': (262, 218),
        '4': (75, 290), '5': (168, 290), '6': (262, 290), '0': (385, 290),
        '7': (75, 362), '8': (168, 362), '9': (262, 362)}
IME_OK = (334, 72)


def sh(*args, timeout=60):
    try:
        r = subprocess.run([HDC, "-t", SN] + list(args), capture_output=True,
                           text=True, encoding="utf-8", errors="ignore", timeout=timeout)
        return (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return "<ERR %s>" % e


def parse_b(b):
    m = re.findall(r"-?\d+", b or "")
    return list(map(int, m[:4])) if len(m) >= 4 else None


def dump(tag):
    sh("shell", "uitest", "dumpLayout", "-p", "/data/local/tmp/%s.json" % tag)
    sh("file", "recv", "/data/local/tmp/%s.json" % tag, "work/qa_shots/%s.json" % tag)
    time.sleep(0.4)
    try:
        return json.load(open("work/qa_shots/%s.json" % tag, encoding="utf-8"))
    except Exception:
        return None


def nodes(root):
    out = []
    if not root: return out
    def w(n):
        out.append(n)
        for c in n.get("children", []): w(c)
    w(root); return out


def texts(root):
    res = []
    for n in nodes(root):
        t = (n.get("attributes", {}).get("text") or "").strip()
        if t: res.append(t)
    return res


def tap(x, y, wait=0.8):
    sh("shell", "uinput", "-T", "-c", str(x), str(y))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, dur=400, wait=1.2):
    sh("shell", "uinput", "-T", "-m", str(x1), str(y1), str(x2), str(y2), str(dur))
    time.sleep(wait)


def money_of(txts, label):
    """取 label 后面的金额文本"""
    for i, t in enumerate(txts):
        if t == label and i + 1 < len(txts):
            m = re.match(r'^([+\-]?\d+\.\d{2})$', txts[i + 1])
            if m: return float(m.group(1))
    return None


def overview():
    """回到概览屏并读今日收支 + 宠物状态（冷启动可能慢，最多重试 4 次）"""
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(1.5)
    sh("shell", "aa", "start", "-b", PKG, "-a", "EntryAbility")
    t = []
    for attempt in range(4):
        time.sleep(4.0)
        d = dump("e4f_ov")
        t = texts(d)
        if any(x == "今日支出" for x in t):
            break
        print("    (概览 dump 第%d次为空/未就绪，重试)" % (attempt + 1))
    return {
        "texts": t,
        "expense": money_of(t, "今日支出"),
        "income": money_of(t, "今日收入"),
        "pet_checked": any("已打卡" in x for x in t),
        "level": next((x for x in t if x.startswith("Lv.")), None),
    }


def main():
    amt = "12"
    print("=" * 60)
    print("T9 E-4/E-5 终验: 手表快记保存 + 宠物联动")
    print("=" * 60)

    ov0 = overview()
    print("\n[保存前] 今日支出=%s 今日收入=%s 宠物打卡=%s 等级=%s"
          % (ov0["expense"], ov0["income"], ov0["pet_checked"], ov0["level"]))
    if ov0["expense"] is None:
        print("!! 概览屏未读到今日支出，屏文本:", ov0["texts"][:20]); sys.exit(1)

    # 上滑到快记屏
    swipe(233, 380, 233, 90, 400, 1.5)
    d = dump("e4f_quick")
    t = texts(d)
    if "快记一笔" not in t:
        print("!! 未滑到快记屏, 当前:", t[:10]); sys.exit(1)
    print("[E-1] 已滑到快记屏")

    # 找金额输入框
    ti = [n for n in nodes(d) if n.get("attributes", {}).get("type") == "TextInput"]
    if not ti:
        print("!! 找不到金额输入框"); sys.exit(1)
    b = parse_b(ti[0].get("attributes", {}).get("bounds"))
    tap((b[0] + b[2]) // 2, (b[1] + b[3]) // 2, 1.5)

    # IME 数字键输入
    for ch in amt:
        tap(*KEYS[ch], wait=0.6)
    tap(*IME_OK, wait=1.5)

    d2 = dump("e4f_typed")
    ti2 = [n for n in nodes(d2) if n.get("attributes", {}).get("type") == "TextInput"]
    got = ti2[0].get("attributes", {}).get("text") if ti2 else "?"
    print("[E-4] 金额框实际内容 = %s" % got)

    # 点保存
    sv = [n for n in nodes(d2)
          if (n.get("attributes", {}).get("text") or "").strip() == "保存"]
    if not sv:
        print("!! 找不到保存按钮"); sys.exit(1)
    a = sv[0].get("attributes", {})
    sb = parse_b(a.get("bounds"))
    print("    保存按钮 enabled=%s bounds=%s" % (a.get("enabled"), sb))
    tap((sb[0] + sb[2]) // 2, (sb[1] + sb[3]) // 2, 3.0)

    ov1 = overview()
    print("\n[保存后] 今日支出=%s 今日收入=%s 宠物打卡=%s 等级=%s"
          % (ov1["expense"], ov1["income"], ov1["pet_checked"], ov1["level"]))

    delta = None
    if ov0["expense"] is not None and ov1["expense"] is not None:
        delta = round(ov1["expense"] - ov0["expense"], 2)
    print("    今日支出变化 = %s (期望 -%s)" % (delta, amt))

    e4 = (delta is not None and abs(delta + float(amt)) < 0.01)
    e5 = ov1["pet_checked"]

    print("\n===== T9 E-4/E-5 结果 =====")
    print("  E-4 手表快记保存落库(概览联动): %s" % ("PASS" if e4 else "FAIL"))
    print("  E-5 宠物打卡联动:               %s" % ("PASS" if e5 else "FAIL"))
    sys.exit(0 if (e4 and e5) else 1)


if __name__ == "__main__":
    main()
