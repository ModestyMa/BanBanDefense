#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T18 尺寸 $r() 资源完整性 + 数值保真 静态校验
- 扫描 entry/wearable 全部 .ets 中 $r('app.float.NAME')
- 比对 entry/wearable 各自 float.json 定义的 name 集合
- ① 被引用却缺失的 key  -> 编译必挂(BLOCKER)
- ② name 末位编码数字 与 float value 是否一致 -> 防脚本写错值导致位移
- ③ 残留尺寸字面量扫描(验收口径① 字面量清零)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MODULES = {
    "entry": os.path.join(ROOT, "entry", "src", "main"),
    "wearable": os.path.join(ROOT, "wearable", "src", "main"),
}

FP_PROPS = {"fontSize", "lineHeight"}  # 这些单位 fp，其余 vp

SIZE_PROP_SINGLE = [
    "fontSize", "width", "height", "padding", "margin", "borderRadius",
    "borderWidth", "space", "strokeWidth", "lineHeight", "radius", "size",
    "maxWidth", "maxHeight", "minWidth", "minHeight",
]


def load_float_names(mod_root):
    """返回 {name: value_str} 与该模块 float.json 路径"""
    p = os.path.join(mod_root, "resources", "base", "element", "float.json")
    if not os.path.exists(p):
        return {}, p
    with open(p, encoding="utf-8") as f:
        doc = json.load(f)
    m = {}
    for item in doc.get("float", []):
        m[item["name"]] = item.get("value", "")
    return m, p


def scan_refs(mod_root):
    refs = set()
    ets_dir = os.path.join(mod_root, "ets")
    if not os.path.isdir(ets_dir):
        return refs
    for dirpath, _, files in os.walk(ets_dir):
        for fn in files:
            if not fn.endswith(".ets"):
                continue
            with open(os.path.join(dirpath, fn), encoding="utf-8") as f:
                txt = f.read()
            for mm in re.finditer(r"\$r\(\s*'app\.float\.([a-zA-Z0-9_]+)'\s*\)", txt):
                refs.add(mm.group(1))
    return refs


def leftover_literals(mod_root):
    """扫描尺寸属性仍以数字字面量传入(验收口径①)"""
    hits = []
    ets_dir = os.path.join(mod_root, "ets")
    if not os.path.isdir(ets_dir):
        return hits
    pat = re.compile(
        r"\.(fontSize|width|height|padding|margin|borderRadius|borderWidth|"
        r"space|strokeWidth|lineHeight|radius|size|maxWidth|maxHeight|"
        r"minWidth|minHeight)\s*\(\s*(\d+(?:\.\d+)?)\s*\)"
    )
    for dirpath, _, files in os.walk(ets_dir):
        for fn in files:
            if not fn.endswith(".ets"):
                continue
            fp = os.path.join(dirpath, fn)
            with open(fp, encoding="utf-8") as f:
                for i, line in enumerate(f, 1):
                    for mm in pat.finditer(line):
                        prop, num = mm.group(1), mm.group(2)
                        # 有意排除 0/1(主程序工程判断); 其余报出
                        if num in ("0", "1"):
                            continue
                        rel = os.path.relpath(fp, ROOT)
                        hits.append(f"{rel}:{i} .{prop}({num})")
    return hits


def main():
    blockers = []
    value_warn = []
    leftover_all = []
    total_refs = 0

    for mod, mod_root in MODULES.items():
        defined, float_path = load_float_names(mod_root)
        refs = scan_refs(mod_root)
        total_refs += len(refs)
        undefined = sorted(refs - set(defined.keys()))
        print(f"\n===== {mod} =====")
        print(f"float.json: {float_path}")
        print(f"  定义资源 {len(defined)} 条 | ets 引用 {len(refs)} 处")
        if undefined:
            print(f"  ❌ 缺失资源(BLOCKER) {len(undefined)} 个:")
            for u in undefined:
                print(f"     - {u}")
            blockers.extend([f"[{mod}] {u}" for u in undefined])
        else:
            print(f"  ✅ 所有 $r 引用均有对应资源")

        # 数值保真: name 末位 _<数字> 与 value 比对
        # 支持小数下划线编码: border_width_1_5 -> 1.5
        bad = []
        for name, val in defined.items():
            mdec = re.search(r"_(\d+)_(\d+)$", name)
            if mdec:
                enc = f"{mdec.group(1)}.{mdec.group(2)}"
            else:
                m = re.search(r"_(\d+(?:\.\d+)?)$", name)
                if not m:
                    continue
                enc = m.group(1)
            vm = re.match(r"^(\d+(?:\.\d+)?)\s*(fp|vp)?$", val.strip())
            if not vm:
                bad.append(f"{name} -> value='{val}' (无法解析)")
                continue
            vnum = vm.group(1)
            unit = vm.group(2) or "vp"
            expect_unit = "fp" if any(name.startswith(p) for p in FP_PROPS) else "vp"
            if vnum != enc or (expect_unit != unit):
                bad.append(f"{name} -> value='{val}' (期望 {enc}{expect_unit})")
        if bad:
            print(f"  ⚠️ 数值保真异常 {len(bad)} 处:")
            for b in bad:
                print(f"     - {b}")
            value_warn.extend([f"[{mod}] {b}" for b in bad])
        else:
            print(f"  ✅ 数值保真: name 编码数字 == value (fp/vp 单位正确)")

        # 残留尺寸字面量 (验收口径①)
        leftover = leftover_literals(mod_root)
        if leftover:
            print(f"  ⚠️ 残留尺寸字面量(>1) {len(leftover)} 处 (验收口径① 应清零):")
            for l in leftover[:40]:
                print(f"     - {l}")
            if len(leftover) > 40:
                print(f"     ... 其余 {len(leftover)-40} 处省略")
            leftover_all.extend(leftover)
        else:
            print(f"  ✅ 无残留尺寸字面量(>1)")

    print("\n========== 汇总 ==========")
    print(f"总 $r 引用: {total_refs} 处")
    print(f"BLOCKER 缺失资源: {len(blockers)}")
    print(f"数值保真异常: {len(value_warn)}")
    print(f"残留尺寸字面量(>1): {len(leftover_all)}")
    if blockers or value_warn:
        print("结果: ❌ 存在需修复项")
        sys.exit(2)
    if leftover_all:
        print("结果: ⚠️ 仅残留字面量(可后续补 0/1 白名单外项), 不阻断编译")
        sys.exit(1)
    print("结果: ✅ 静态校验全过")
    sys.exit(0)


if __name__ == "__main__":
    main()
