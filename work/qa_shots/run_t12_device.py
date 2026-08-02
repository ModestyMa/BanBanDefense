#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T12 整包回归（上架前清单）真机验证（多设备版）
用法:
  HDC_SERIAL=192.168.43.6:33359 python run_t12_device.py phone
  HDC_SERIAL=192.168.43.27:35521 python run_t12_device.py tablet
  HDC_SERIAL=192.168.43.202:34021 python run_t12_device.py watch
依据: docs/handover/07_里程碑与验收清单.md §3.5 整包回归（上架前 30 分钟清单）
覆盖:
  - 冷启动耗时(force-stop -> aa start -> 首页关键文本出现)
  - 四大模块核心路径连走(首页/记账/倒数日/番茄/设置 或 手表三屏)
  - 关键写入链路真实落库(记账/倒数日/快记 尽力写入+回读)
  - App 存活 + hilog app 级错误扫描
  - 首启隐私政策弹窗 / 卸载清空 / 升级保留 见 run_t12_data.py (C 阶段)
依赖: run_t18_device.py (hdc/tap/snap/零尺寸封装)
"""
import subprocess, json, time, sys, os, re

# 必须在 import run_t18_device 前设好 HDC_SERIAL (run_t18 顶部读取)
if len(sys.argv) > 2:
    os.environ["HDC_SERIAL"] = sys.argv[2]
import run_t18_device as T

PKG = T.PKG
SERIAL = T.SERIAL
RESULT = {"mode": sys.argv[1] if len(sys.argv) > 1 else "phone", "serial": SERIAL}


def find_input(root):
    """找首个可编辑输入控件(金额/备注等)"""
    res = []

    def walk(n):
        a = n.get("attributes", {})
        tp = a.get("type", "")
        ph = a.get("placeholder", "") or ""
        if tp in ("TextInput", "TextField", "TextArea", "Search") or "0.00" in ph or "0.0" in ph:
            if not res:
                res.append(n)
        for c in n.get("children", []):
            walk(c)
    if root:
        walk(root)
    return res[0] if res else None


def find_save(d):
    """放宽保存按钮匹配: 文本 保存/完成/确定/✔/✓/√ 或最右下角可点按钮"""
    cands = []

    def walk(n):
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        ty = a.get("type", "")
        b = T.bounds_of(n)
        if b and (ty in ("Button", "ListItem") or t):
            if t in ("保存", "完成", "确定") or any(x in t for x in ("✔", "✓", "√")):
                cands.append((n, b, 0))
            elif "保存" in t or "完成" in t or "确定" in t:
                cands.append((n, b, 1))
        for c in n.get("children", []):
            walk(c)
    if d:
        walk(d)
    if cands:
        cands.sort(key=lambda x: x[2])
        return cands[0][0]
    # 兜底: 最右下角 Button/可点节点
    best = None
    best_score = -1

    def walk2(n):
        nonlocal best, best_score
        a = n.get("attributes", {})
        ty = a.get("type", "")
        b = T.bounds_of(n)
        if b and ty in ("Button", "ListItem"):
            score = b[2] + b[3]
            if score > best_score:
                best_score = score
                best = n
        for c in n.get("children", []):
            walk2(c)
    if d:
        walk2(d)
    return best


def dump_now():
    """抓当前布局树(写文件+recv 可靠路径)，用于轮询/快速检测"""
    T.sh("shell", "uitest", "dumpLayout", "-p", "/data/local/tmp/_t12_tmp.json", timeout=20)
    time.sleep(0.3)
    T.sh("file", "recv", "/data/local/tmp/_t12_tmp.json", "work/qa_shots/_t12_tmp.json")
    p = "work/qa_shots/_t12_tmp.json"
    if not os.path.exists(p):
        return None
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return None


def collect_texts(root):
    txts = []

    def walk(n):
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if t:
            txts.append(t)
        for c in n.get("children", []):
            walk(c)
    if root:
        walk(root)
    return txts


def cold_start_timing(key_texts=("伴伴", "今日", "Lv", "首页", "倒数日", "记账"), timeout=8.0):
    """force-stop 后冷启动，测量到首页关键文本出现的耗时(秒)"""
    T.sh("shell", "aa", "force-stop", PKG)
    time.sleep(1.2)
    t0 = time.time()
    T.sh("shell", "aa", "start", "-b", PKG, "-a", "EntryAbility")
    cost = None
    n = int(timeout / 0.3)
    for _ in range(n):
        time.sleep(0.3)
        d = dump_now()
        if d:
            joined = " ".join(collect_texts(d))
            if any(k in joined for k in key_texts):
                cost = time.time() - t0
                break
    if cost is None:
        cost = round(time.time() - t0, 2)  # 超时，记总耗时
    return cost


def add_expense(amount="12.34"):
    """进记账页 -> 聚焦金额输入框 -> 输入 -> 保存 -> 回读。返回 (ok, info)"""
    T.tap_text("记账", wait=1.2)
    d = dump_now()
    if not d:
        return False, "记账页 dump 失败"
    target = find_input(d)
    if not target:
        return False, "未找到金额输入框"
    b = T.bounds_of(target)
    cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    T.tap(cx, cy, wait=0.8)
    T.sh("shell", "uitest", "uiInput", "text", amount, timeout=15)
    time.sleep(0.6)
    # 收键盘: 点标题区(避免横屏软键盘遮挡保存按钮)
    hroot = dump_now()
    if hroot:
        nodes = T.find_text_nodes(hroot, "记账")
        if nodes:
            bb = T.bounds_of(nodes[0])
            if bb:
                T.tap((bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2, wait=0.5)
    d2 = dump_now()
    save = find_save(d2)
    if not save:
        return False, "未找到保存按钮(可能软键盘遮挡)"
    sb = T.bounds_of(save)
    T.tap((sb[0] + sb[2]) // 2, (sb[1] + sb[3]) // 2, wait=1.2)
    d3 = dump_now()
    txts = collect_texts(d3) if d3 else []
    hit = [t for t in txts if amount in t or "12.34" in t]
    return (len(hit) > 0), f"回读命中={hit[:3]}"


def add_countdown(title="T12回归测试"):
    """进倒数日 -> 点 + -> 输入标题 -> 保存 -> 回读。返回 (ok, info)"""
    T.tap_text("倒数日", wait=1.2)
    d = dump_now()
    if not d:
        return False, "倒数日页 dump 失败"
    plus = None

    def walk(n):
        nonlocal plus
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if (t == "+" or t == "新增" or t == "添加") and plus is None:
            plus = n
        for c in n.get("children", []):
            walk(c)
    walk(d)
    if not plus:
        return False, "未找到新增(+)按钮"
    pb = T.bounds_of(plus)
    T.tap((pb[0] + pb[2]) // 2, (pb[1] + pb[3]) // 2, wait=1.0)
    time.sleep(0.5)
    # 找标题输入框并输入
    d2 = dump_now()
    inp = None

    def walk2(n):
        nonlocal inp
        a = n.get("attributes", {})
        tp = a.get("type", "")
        ph = a.get("placeholder", "") or ""
        if (tp in ("TextInput", "TextField")) and inp is None:
            inp = n
        for c in n.get("children", []):
            walk2(c)
    if d2:
        walk2(d2)
    if inp:
        b = T.bounds_of(inp)
        T.tap((b[0] + b[2]) // 2, (b[1] + b[3]) // 2, wait=0.6)
        T.sh("shell", "uitest", "uiInput", "text", title, timeout=15)
        time.sleep(0.5)
    # 找保存
    d3 = dump_now()
    save = None

    def walk3(n):
        nonlocal save
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if t in ("保存", "完成", "确定") and save is None:
            save = n
        for c in n.get("children", []):
            walk3(c)
    if d3:
        walk3(d3)
    if not save:
        return False, "未找到保存按钮(可能软键盘遮挡)"
    sb = T.bounds_of(save)
    T.tap((sb[0] + sb[2]) // 2, (sb[1] + sb[3]) // 2, wait=1.2)
    d4 = dump_now()
    txts = collect_texts(d4) if d4 else []
    hit = [t for t in txts if title in t]
    return (len(hit) > 0), f"回读命中={hit[:3]}"


def walk_phone(mode):
    print(f"\n===== [{mode}] 冷启动计时 =====")
    cost = cold_start_timing()
    RESULT["cold_start_s"] = cost
    print(f"  冷启动耗时 = {cost}s (阈值 <1.5s)")
    # 四大模块连走
    pages = ["首页", "番茄", "记账", "倒数日"]
    for p in pages:
        ok = T.tap_text(p, wait=1.2)
        if ok:
            r = T.snap(f"t12_{mode}_{p}")
            T.zero_bounds_summary(f"t12_{mode}_{p}", r)
        else:
            print(f"  [SKIP] tab '{p}' 未找到")
    # 设置页(⚙)
    T.tap_text("⚙", wait=1.2)
    rs = T.snap(f"t12_{mode}_设置")
    T.zero_bounds_summary(f"t12_{mode}_设置", rs)
    # 关键写入: 记账
    print(f"===== [{mode}] 记账写入尝试 =====")
    ok, info = add_expense("12.34")
    RESULT["expense_write"] = {"ok": ok, "info": info}
    print(f"  记账新增: {'✅' if ok else '⚠️受限'} {info}")
    # 关键写入: 倒数日
    print(f"===== [{mode}] 倒数日写入尝试 =====")
    ok2, info2 = add_countdown("T12回归")
    RESULT["countdown_write"] = {"ok": ok2, "info": info2}
    print(f"  倒数日新增: {'✅' if ok2 else '⚠️受限'} {info2}")
    # 回首页收尾
    T.tap_text("首页", wait=1.0)


def walk_watch():
    print(f"\n===== [watch] 冷启动计时 =====")
    cost = cold_start_timing(key_texts=("伴伴", "今日", "概览", "快记", "Lv"))
    RESULT["cold_start_s"] = cost
    print(f"  冷启动耗时 = {cost}s")
    r = T.snap("t12_watch_home")
    T.zero_bounds_summary("t12_watch_home", r)
    # 快记写入尝试(复用 E-4 路径: 点金额 -> IME 键 -> 确认回填 -> 保存)
    print(f"===== [watch] 快记写入尝试 =====")
    ok, info = watch_quick_add("88")
    RESULT["expense_write"] = {"ok": ok, "info": info}
    print(f"  快记新增: {'✅' if ok else '⚠️'} {info}")
    # 竖滑三屏
    for i in range(2):
        T.swipe(234, 360, 234, 120, ms=400, wait=1.2)
        rr = T.snap(f"t12_watch_{i+2}")
        T.zero_bounds_summary(f"t12_watch_{i+2}", rr)


def watch_quick_add(amount="88"):
    """手表快记: 遍历三屏找金额输入区 -> IME 输入 -> 确认键回填 -> 保存 -> 回读"""
    target = None
    for attempt in range(3):
        d = dump_now()
        if d:
            target = find_input(d)
            if target:
                break
        T.swipe(234, 360, 234, 120, ms=400, wait=1.2)  # 上滑到下一屏
    if not target:
        return False, "三屏均未找到金额输入区"
    b = T.bounds_of(target)
    T.tap((b[0] + b[2]) // 2, (b[1] + b[3]) // 2, wait=1.0)
    # IME 数字键坐标(来自 E-4 v10 实测)
    keys = {'1': (62, 223), '2': (176, 223), '3': (290, 223), '.': (404, 223),
            '4': (62, 285), '5': (176, 285), '6': (290, 285),
            '7': (62, 347), '8': (176, 347), '9': (290, 347), '0': (404, 285)}
    IME_OK = (334, 72)
    for ch in amount:
        if ch in keys:
            T.tap(*keys[ch], wait=0.25)
    T.tap(*IME_OK, wait=0.6)  # 确认回填
    # 收 IME 键盘: 点标题区, 避免遮住底部保存按钮
    h = dump_now()
    if h:
        ns = T.find_text_nodes(h, "快记一笔")
        if ns:
            bb = T.bounds_of(ns[0])
            T.tap((bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2, wait=0.5)
    d = dump_now()
    save = find_save(d)
    if not save:
        return False, "未找到保存按钮"
    sb = T.bounds_of(save)
    T.tap((sb[0] + sb[2]) // 2, (sb[1] + sb[3]) // 2, wait=1.2)
    # 保存后回到概览屏读取"今日支出"(强下滑回概览, 最多3次)
    d2 = None
    for _ in range(3):
        d2 = dump_now()
        if d2 and "今日支出" in " ".join(collect_texts(d2)):
            break
        T.swipe(234, 120, 234, 360, ms=500, wait=1.0)
    txts = collect_texts(d2) if d2 else []
    hit = [t for t in txts if amount in t]
    return (len(hit) > 0), f"回读命中={hit[:3]}"


def error_scan():
    """hilog 抓 app 级 error/exception/资源缺失"""
    try:
        T.sh("shell", "hilog", "-r", timeout=10)
    except Exception:
        pass
    T.start_app()
    time.sleep(1.5)
    try:
        out = T.sh("shell", "hilog", "-x", timeout=8)
    except Exception as e:
        out = getattr(e, "stdout", "") or ""
    lines = out.splitlines()
    # 仅计 app 自身进程的错误: 含包名 且 (级别 E/F 或 含 Exception/Crash/abort/ANR)
    pat = re.compile(r" com\.modestyma\.banban |com\.modestyma\.banban[:\.]", re.I)
    errpat = re.compile(r" [EF] |Exception|Crash|crash|abort|ANR|failed to|Cannot|undefined", re.I)
    hits = [l for l in lines if pat.search(l) and errpat.search(l)]
    RESULT["app_errors"] = len(hits)
    for h in hits[:20]:
        print("  ERR:", h.strip()[:150])
    if not hits:
        print("  ✅ 无 app 级 error/exception/资源缺失日志")


def main():
    mode = RESULT["mode"]
    print(f"\n########## T12 整包回归 [{mode}] serial={SERIAL} ##########")
    if mode == "watch":
        walk_watch()
    else:
        walk_phone(mode)
    alive = PKG in T.sh("shell", "ps", "-ef")
    RESULT["alive"] = alive
    print(f"  App 存活: {alive}")
    print(f"===== [{mode}] hilog 错误扫描 =====")
    error_scan()
    print("RESULT_JSON=" + json.dumps(RESULT, ensure_ascii=False))
    print(f"########## [{mode}] 完成 ##########")


if __name__ == "__main__":
    main()
