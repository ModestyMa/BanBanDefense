#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T18 四端尺寸 $r() 真机回归（多设备版）
用法:
  HDC_SERIAL=192.168.43.6:33359 python run_t18_device.py phone
  HDC_SERIAL=192.168.43.27:35521 python run_t18_device.py tablet
  HDC_SERIAL=192.168.43.202:34021 python run_t18_device.py watch
依赖: hdc (DevEco SDK)
- 启动 App -> 走查关键页 -> 每页 snapshot + dumpLayout
- 自动检测零/负尺寸控件(尺寸回归坏象)
- 截图存 work/qa_shots/t18_<mode>_*.jpeg 供视觉确认(数值保真故应与改造前一致)
"""
import subprocess, json, time, sys, os, re

HDC = r"D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PKG = "com.modestyma.banban"
OUT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(OUT))
os.chdir(PROJ)

SERIAL = os.environ.get("HDC_SERIAL", "")


def sh(*args, timeout=60):
    cmd = [HDC]
    if SERIAL:
        cmd += ["-t", SERIAL]
    cmd += list(args)
    r = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="ignore", timeout=timeout)
    return (r.stdout or "") + (r.stderr or "")


def tap(x, y, wait=1.0):
    sh("shell", "uinput", "-T", "-c", str(int(x)), str(int(y)))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, ms=400, wait=1.0):
    sh("shell", "uinput", "-T", "-m", str(x1), str(y1), str(x2), str(y2), str(ms))
    time.sleep(wait)


def start_app():
    sh("shell", "aa", "start", "-b", PKG, "-a", "EntryAbility")
    time.sleep(2.5)


def snap(tag):
    """截图 + dump 布局，返回 dump 解析(根节点或 None)"""
    sh("shell", "snapshot_display", "-f", f"/data/local/tmp/{tag}.jpeg")
    sh("file", "recv", f"/data/local/tmp/{tag}.jpeg", f"work/qa_shots/{tag}.jpeg")
    sh("shell", "uitest", "dumpLayout", "-p", f"/data/local/tmp/{tag}.json")
    time.sleep(0.6)
    sh("file", "recv", f"/data/local/tmp/{tag}.json", f"work/qa_shots/{tag}.json")
    p = f"work/qa_shots/{tag}.json"
    if not os.path.exists(p):
        return None
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print(f"  [WARN] {tag} 布局解析失败: {e}")
        return None


def bounds_of(node):
    a = node.get("attributes", {})
    b = a.get("bounds", "")
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
    if not m:
        return None
    return tuple(int(x) for x in m.groups())


def find_text_nodes(root, text):
    """返回 root 下所有 text==text 的节点"""
    res = []

    def walk(n):
        a = n.get("attributes", {})
        if (a.get("text") or "").strip() == text:
            res.append(n)
        for c in n.get("children", []):
            walk(c)
    walk(root)
    return res


def tap_text(text, wait=1.0):
    """点底部最靠下的同名文本(通常是 Tab)"""
    d = snap(f"_tmp_{text}")
    if not d:
        return False
    nodes = find_text_nodes(d, text)
    if not nodes:
        print(f"  [WARN] 未找到文本 '{text}'")
        return False
    # 选 y2 最大(最靠底)的节点 = TabBar
    best = max(nodes, key=lambda n: (bounds_of(n) or (0, 0, 0, 0))[3])
    b = bounds_of(best)
    if not b:
        return False
    cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    tap(cx, cy, wait)
    return True


def check_zero_bounds(tag, root):
    """检测可见控件零/负尺寸(尺寸回归坏象)，返回告警列表"""
    warns = []

    def walk(n, depth=0):
        b = bounds_of(n)
        if b:
            x1, y1, x2, y2 = b
            w, h = x2 - x1, y2 - y1
            a = n.get("attributes", {})
            t = (a.get("text") or "").strip()
            # 仅报有文本或常见容器且尺寸异常的
            if (w <= 0 or h <= 0) and (t or a.get("type") in ("Button", "Text", "Image", "ListItem")):
                warns.append(f"{a.get('type','?')} '{t}' 尺寸={w}x{h} @{b}")
        for c in n.get("children", []):
            walk(c, depth + 1)
    if root:
        walk(root)
    return warns


def zero_bounds_summary(tag, root):
    w = check_zero_bounds(tag, root)
    if w:
        print(f"  ⚠️ [{tag}] 零/负尺寸控件 {len(w)}: " + "; ".join(w[:8]))
    else:
        print(f"  ✅ [{tag}] 无零/负尺寸控件")
    return w


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "phone"
    if len(sys.argv) > 2:
        os.environ["HDC_SERIAL"] = sys.argv[2]
        global SERIAL
        SERIAL = sys.argv[2]
    print(f"\n########## T18 真机回归 [{mode}] serial={SERIAL} ##########")
    start_app()
    root = snap(f"t18_{mode}_home")
    zero_bounds_summary(f"t18_{mode}_home", root)

    if mode in ("phone", "tablet"):
        tabs = ["番茄", "记账", "倒数日", "首页"]
        for t in tabs:
            ok = tap_text(t, wait=1.2)
            if ok:
                r = snap(f"t18_{mode}_{t}")
                zero_bounds_summary(f"t18_{mode}_{t}", r)
            else:
                print(f"  [SKIP] tab '{t}' 未找到")
        # 设置页: 顶部 ⚙ 进入
        ok = tap_text("⚙", wait=1.2)
        if ok:
            r = snap(f"t18_{mode}_设置")
            zero_bounds_summary(f"t18_{mode}_设置", r)
        else:
            print(f"  [SKIP] '⚙' 设置入口未找到")
    else:  # watch: 竖滑三屏(T21 修复后竖向)
        for i in range(2):
            swipe(234, 360, 234, 120, ms=400, wait=1.2)  # 圆屏 466 中心附近上滑
            r = snap(f"t18_watch_{i+2}")
            zero_bounds_summary(f"t18_watch_{i+2}", r)

    alive = PKG in sh("shell", "ps", "-ef")
    print(f"  App 存活: {alive}")
    print(f"########## [{mode}] 完成 ##########")


if __name__ == "__main__":
    main()
