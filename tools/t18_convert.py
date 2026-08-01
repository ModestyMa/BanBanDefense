#!/usr/bin/env python3
# T18 辅助脚本：全量存量数字尺寸字面量 -> $r('app.float.<prop>_<value>')
# 单值形式: .prop(N)  -> .prop($r('app.float.<prop>_<N>'))
# 对象形式: .prop({k:N}) -> .prop({k:$r('app.float.<prop>_<k>_<N>')})
# 单位: fontSize/lineHeight -> fp；其余尺寸 -> vp。
# 排除整数 0 与 1（布局默认/边界值，改 $r 无收益且易误伤）。
import re
import os
import sys
import json

ROOT = r'C:\Users\Administrator\Desktop\HarmonyAPP'
MODULES = {
    'entry': os.path.join(ROOT, 'entry/src/main/ets'),
    'wearable': os.path.join(ROOT, 'wearable/src/main/ets'),
}
FLOAT_PATH = {
    'entry': os.path.join(ROOT, 'entry/src/main/resources/base/element/float.json'),
    'wearable': os.path.join(ROOT, 'wearable/src/main/resources/base/element/float.json'),
}
SINGLE_PROPS = ['fontSize', 'width', 'height', 'padding', 'margin', 'borderRadius',
                'borderWidth', 'top', 'bottom', 'left', 'right', 'space', 'strokeWidth',
                'lineHeight', 'maxWidth', 'maxHeight', 'minWidth', 'minHeight', 'radius', 'size']
OBJ_PROPS = ['padding', 'margin', 'size', 'border', 'constraintSize']
FP_PROPS = {'fontSize', 'lineHeight'}

single_re = re.compile(r'\.(' + '|'.join(SINGLE_PROPS) + r')' + r'\((\d+(?:\.\d+)?)\)')
obj_re = re.compile(r'\.(' + '|'.join(OBJ_PROPS) + r')' + r'\(\{([^}]*)\}\)')
inner_re = re.compile(r'(\w+)\s*:\s*(\d+(?:\.\d+)?)')

DRY = '--dry-run' in sys.argv


def should_skip_num(v: str) -> bool:
    # 排除整数 0 / 1
    try:
        f = float(v)
    except ValueError:
        return True
    if f == int(f) and int(f) in (0, 1):
        return True
    return False


def name_for(prop: str, value: str, subkey: str = '') -> str:
    if subkey:
        return f'{prop}_{subkey}_{value}'.replace('.', '_')
    return f'{prop}_{value}'.replace('.', '_')


def unit_for(prop: str) -> str:
    return 'fp' if prop in FP_PROPS else 'vp'


def collect():
    plan = {}  # mod -> list of (file, line, old, new, (resname, resval))
    res_needed = {}  # mod -> {resname: resval}
    for mod, path in MODULES.items():
        res_needed[mod] = {}
        plan[mod] = []
        for dp, _, fns in os.walk(path):
            for fn in fns:
                if not fn.endswith('.ets'):
                    continue
                fp = os.path.join(dp, fn)
                rel = os.path.relpath(fp, ROOT)
                with open(fp, encoding='utf-8') as f:
                    lines = f.readlines()
                new_lines = []
                for i, line in enumerate(lines, 1):
                    nl = line
                    # 单值
                    def repl_single(m):
                        p, v = m.group(1), m.group(2)
                        if should_skip_num(v):
                            return m.group(0)
                        rn = name_for(p, v)
                        rv = f'{v}{unit_for(p)}'
                        res_needed[mod][rn] = rv
                        return f'.{p}($r(\'app.float.{rn}\'))'
                    nl, n_single = single_re.subn(repl_single, nl)
                    # 对象形式
                    def repl_obj(m):
                        p = m.group(1)
                        body = m.group(2)

                        def repl_inner(mm):
                            k, v = mm.group(1), mm.group(2)
                            if should_skip_num(v):
                                return mm.group(0)
                            rn = name_for(p, v, k)
                            rv = f'{v}{unit_for(p)}'
                            res_needed[mod][rn] = rv
                            return f'{k}:$r(\'app.float.{rn}\')'
                        new_body = inner_re.sub(repl_inner, body)
                        return f'.{p}({{{new_body}}})'
                    nl, n_obj = obj_re.subn(repl_obj, nl)
                    if n_single or n_obj:
                        plan[mod].append((rel, i, line.rstrip('\n'), nl.rstrip('\n')))
                    new_lines.append(nl)
                if not DRY and (new_lines != lines):
                    with open(fp, 'w', encoding='utf-8') as f:
                        f.writelines(new_lines)
    return plan, res_needed


def update_float(mod, res_needed):
    fp = FLOAT_PATH[mod]
    existing = {}
    if os.path.exists(fp):
        with open(fp, encoding='utf-8') as f:
            data = json.load(f)
    else:
        data = {'float': []}
    floats = data.setdefault('float', [])
    for item in floats:
        existing[item['name']] = item['value']
    added = 0
    for name, val in sorted(res_needed.items()):
        if name in existing:
            continue
        floats.append({'name': name, 'value': val})
        existing[name] = val
        added += 1
    if not DRY:
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        with open(fp, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
    return added, len(floats)


def main():
    plan, res_needed = collect()
    total_changes = 0
    for mod in MODULES:
        changes = plan[mod]
        added, total = update_float(mod, res_needed[mod])
        total_changes += len(changes)
        print(f'=== {mod} ===')
        print(f'  code changes: {len(changes)} | float resources needed: {len(res_needed[mod])} | added to float.json: {added} (total {total})')
        if DRY:
            for rel, i, old, new in changes[:8]:
                print(f'  [{rel}:{i}]')
                print(f'    - {old}')
                print(f'    + {new}')
            if len(changes) > 8:
                print(f'    ... and {len(changes) - 8} more')
    print(f'\nTOTAL code changes (dry-run): {total_changes}')


if __name__ == '__main__':
    main()
