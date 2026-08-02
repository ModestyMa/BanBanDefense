#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BUG-008 验证: 记账保存后列表是否【立刻】刷新(不冷启动)"""
import subprocess, json, time, os, re, sys
HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(PROJ)
SERIAL = os.environ.get("HDC_SERIAL", "192.168.43.27:35521")
import run_t18_device as T
T.SERIAL = SERIAL

def bnd(n): return T.bounds_of(n)

def dump(tag):
    T.snap(tag)
    try:
        return json.load(open(f"work/qa_shots/{tag}.json", encoding="utf-8"))
    except Exception:
        return None

def find_text(root, text):
    res = []
    if not root: return res
    def w(n):
        if ((n.get("attributes", {}).get("text") or "").strip()) == text: res.append(n)
        for c in n.get("children", []): w(c)
    w(root); return res

def find_all(root, pred):
    res = []
    if not root: return res
    def w(n):
        if pred(n): res.append(n)
        for c in n.get("children", []): w(c)
    w(root); return res

def texts(root):
    out = []
    def w(n):
        t = (n.get("attributes", {}).get("text") or "").strip()
        if t: out.append(t)
        for c in n.get("children", []): w(c)
    if root: w(root)
    return out

def inputText(x, y, s):
    subprocess.run([HDC, "-t", SERIAL, "shell", "uitest", "uiInput", "inputText", str(x), str(y), s],
                   capture_output=True, text=True, timeout=15)

def save_one(amt, tag_prefix, income=False):
    d = dump(tag_prefix + "_list")
    if income:
        inc = find_text(d, "收入")
        if inc:
            ib = bnd(inc[0]); T.tap((ib[0]+ib[2])//2, (ib[1]+ib[3])//2, 0.6)
            d = dump(tag_prefix + "_inc")
    ins = find_all(d, lambda n: (n.get("attributes", {}).get("type") in ("TextInput", "TextField")))
    if not ins:
        print("!! 找不到金额输入框"); return None
    ab = bnd(ins[0]); cx, cy = (ab[0]+ab[2])//2, (ab[1]+ab[3])//2
    T.tap(cx, cy, 0.8)
    inputText(cx, cy, amt); time.sleep(1.0)
    d2 = dump(tag_prefix + "_amt")
    cur = find_all(d2, lambda n: (n.get("attributes", {}).get("type") in ("TextInput", "TextField")))
    got = (cur[0].get("attributes", {}).get("text") if cur else "?")
    print(f"  输入金额={amt} 框内实际={got}")
    sv = find_all(d2, lambda n: (n.get("attributes", {}).get("text") or "").strip() in ("保存", "完成", "确定"))
    if not sv:
        print("!! 找不到保存按钮"); return None
    sb = bnd(sv[0])
    T.tap((sb[0]+sb[2])//2, (sb[1]+sb[3])//2, 1.0)
    time.sleep(2.5)
    return dump(tag_prefix + "_after")

def main():
    ts = int(time.time())
    amt1 = "%d.%02d" % (ts % 800 + 100, ts % 90 + 5)          # 支出
    amt2 = "%d.%02d" % ((ts + 371) % 800 + 100, (ts + 7) % 90 + 5)  # 同日再来一笔

    T.start_app(); time.sleep(3)
    d = dump("v_home")
    ns = find_text(d, "记账")
    if not ns:
        print("!! 首页找不到 记账 入口"); sys.exit(1)
    best = max(ns, key=lambda n: (bnd(n) or (0, 0, 0, 0))[3]); b = bnd(best)
    T.tap((b[0]+b[2])//2, (b[1]+b[3])//2, 2.0)

    before = texts(dump("v_before"))
    money_before = [t for t in before if re.search(r'^[+\-]\d+\.\d{2}$', t)]
    print("保存前列表金额:", money_before)

    print("\n--- 第1笔(支出 %s) ---" % amt1)
    d3 = save_one(amt1, "v1")
    after1 = texts(d3) if d3 else []
    m1 = [t for t in after1 if re.search(r'^[+\-]\d+\.\d{2}$', t)]
    hit1 = ("-" + amt1) in after1
    print("  保存后列表金额:", m1)
    print("  ==> 立刻出现 -%s : %s" % (amt1, hit1))

    print("\n--- 第2笔(同日再来一笔 支出 %s) ---" % amt2)
    d4 = save_one(amt2, "v2")
    after2 = texts(d4) if d4 else []
    m2 = [t for t in after2 if re.search(r'^[+\-]\d+\.\d{2}$', t)]
    hit2 = ("-" + amt2) in after2
    print("  保存后列表金额:", m2)
    print("  ==> 立刻出现 -%s : %s" % (amt2, hit2))
    print("  ==> 第1笔仍在   : %s" % (("-" + amt1) in after2))

    print("\n===== BUG-008 验证结果 =====")
    ok = hit1 and hit2 and (("-" + amt1) in after2)
    print("同日连续两笔均即时刷新:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
