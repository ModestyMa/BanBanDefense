#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""记账保存 bug 定位: 保存一笔并抓 TxRepoDebug / AccountViewModel / AccountPage hilog"""
import subprocess, json, time, os, re, threading
HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(PROJ)
SERIAL = os.environ.get("HDC_SERIAL", "192.168.43.27:35521")
import run_t18_device as T
T.SERIAL = SERIAL

LOG_BUF = []

def bnd(n): return T.bounds_of(n)

def dump(tag):
    T.snap(tag)
    p = f"work/qa_shots/{tag}.json"
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return None

def find_text(root, text):
    res = []
    if not root: return res
    def w(n):
        if ((n.get("attributes", {}).get("text") or "").strip()) == text: res.append(n)
        for c in n.get("children", []): w(c)
    w(root); return res

def find_first(root, pred):
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

def log_reader(stop_evt):
    p = subprocess.Popen([HDC, "-t", SERIAL, "shell", "hilog", "-x"],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, encoding="utf-8", errors="ignore", bufsize=1)
    try:
        for line in p.stdout:
            if stop_evt.is_set(): break
            if re.search(r"TxRepoDebug|AccountViewModel|AccountPage|JsApp|ArkTS|Error|Exception|Fault|RdbStoreImpl|SQLite|sqlite", line) \
                    and not re.search(r"AceTextField|AceFocus|AceOverlay|InputManagerImpl|ClientMsgHandler|WMSEvent|InputKeyFlow|AceTextInput|Hint_To_Type|ImsaKit|accessibility|RdbManager", line):
                LOG_BUF.append(line.rstrip())
    except Exception:
        pass
    finally:
        try: p.kill()
        except Exception: pass

def main():
    amt = "76.54"
    subprocess.run([HDC, "-t", SERIAL, "shell", "hilog", "-r"], capture_output=True, timeout=15)
    T.start_app(); time.sleep(2.5)
    d = dump("g_home")
    ns = find_text(d, "记账")
    best = max(ns, key=lambda n: (bnd(n) or (0, 0, 0, 0))[3]); b = bnd(best)
    T.tap((b[0]+b[2])//2, (b[1]+b[3])//2, 1.5)
    d = dump("g_list")
    ins = find_first(d, lambda n: (n.get("attributes", {}).get("type") in ("TextInput", "TextField")))
    if not ins:
        print("!! 找不到金额输入框"); return
    ab = bnd(ins[0]); cx, cy = (ab[0]+ab[2])//2, (ab[1]+ab[3])//2
    T.tap(cx, cy, 0.8)
    inputText(cx, cy, amt); time.sleep(1.0)
    d2 = dump("g_after_amt")
    cur = find_first(d2, lambda n: (n.get("attributes", {}).get("type") in ("TextInput", "TextField")))
    print("金额框文本 =", (cur[0].get("attributes", {}).get("text") if cur else "?"))

    # 开日志线程后再点保存
    stop = threading.Event()
    th = threading.Thread(target=log_reader, args=(stop,), daemon=True); th.start()
    time.sleep(1.0)

    d3 = dump("g_before_save")
    sv = find_first(d3, lambda n: (n.get("attributes", {}).get("text") or "").strip() in ("保存", "完成", "确定"))
    if not sv:
        print("!! 找不到保存按钮"); stop.set(); return
    sb = bnd(sv[0])
    print("保存按钮 bounds =", sb)
    T.tap((sb[0]+sb[2])//2, (sb[1]+sb[3])//2, 1.0)
    time.sleep(4.0)
    stop.set(); time.sleep(0.5)

    d4 = dump("g_after_save")
    allt = texts(d4)
    print("含 +%s :" % amt, ("+" + amt) in allt)
    print("金额类文本:", [t for t in allt if re.search(r'[+\-]\d+\.\d+', t)])
    print("\n===== HILOG (%d 行) =====" % len(LOG_BUF))
    for l in LOG_BUF[-120:]:
        print(l)

if __name__ == "__main__":
    main()
