#!/usr/bin/env python3
# 诊断手表快记写入链路中间态
import os, sys, time
os.environ['HDC_SERIAL'] = '192.168.43.202:34021'
import run_t12_device as M

PKG = M.PKG


def txts(d):
    return [t for t in M.collect_texts(d) if t]


M.T.sh("shell", "aa", "force-stop", PKG)
time.sleep(1.5)
M.T.sh("shell", "aa", "start", "-b", PKG, "-a", "EntryAbility")
time.sleep(3.5)

d = M.dump_now()
print("[1] 首屏文本:", txts(d)[:8])

M.T.swipe(234, 360, 234, 120, ms=400, wait=1.5)
d = M.dump_now()
print("[2] swipe后文本:", txts(d)[:8])

inp = M.find_input(d)
print("[3] input找到:", M.T.bounds_of(inp) if inp else None)
if not inp:
    print("  !! 未切到快记屏, 终止")
    sys.exit(0)

b = M.T.bounds_of(inp)
M.T.tap((b[0] + b[2]) // 2, (b[1] + b[3]) // 2, wait=1.0)
keys = {'1': (62, 223), '2': (176, 223), '3': (290, 223), '.': (404, 223),
        '4': (62, 285), '5': (176, 285), '6': (290, 285),
        '7': (62, 347), '8': (176, 347), '9': (290, 347), '0': (404, 285)}
for ch in "12.34":
    if ch in keys:
        M.T.tap(*keys[ch], wait=0.25)
M.T.tap(334, 72, wait=0.6)
d = M.dump_now()
print("[4] IME后屏文本:", txts(d)[:12])
# 看金额框当前文本(找 input 的 text)
if d:
    def walk(n):
        a = n.get("attributes", {})
        if "Input" in a.get("type", ""):
            print("    input.text =", repr((a.get("text") or "").strip()), a.get("bounds", ""))
        for c in n.get("children", []):
            walk(c)
    walk(d)

# 收键盘
h = M.dump_now()
ns = M.T.find_text_nodes(h, "快记一笔")
print("[5] 找到标题'快记一笔':", len(ns) > 0)
if ns:
    bb = M.T.bounds_of(ns[0])
    M.T.tap((bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2, wait=0.5)
d = M.dump_now()
print("[6] 收键盘后屏文本:", txts(d)[:12])
save = M.find_save(d)
print("[7] save找到:", M.T.bounds_of(save) if save else None)
if save:
    sb = M.T.bounds_of(save)
    M.T.tap((sb[0] + sb[2]) // 2, (sb[1] + sb[3]) // 2, wait=1.5)
    d3 = M.dump_now()
    print("[8] 保存后屏文本:", txts(d3)[:14])
