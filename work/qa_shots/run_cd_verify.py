# A: 关闭提醒开关后能否保存（验证根因+规避方案） B: 编辑模式是否同样报错 C: 删除脏数据
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def parse_b(b):
    m = re.findall(r'-?\d+', b or '')
    return list(map(int, m[:4])) if len(m) >= 4 else None


def dump(tag):
    sh('shell', 'snapshot_display', '-f', f'/data/local/tmp/{tag}.jpeg')
    sh('shell', 'uitest', 'dumpLayout', '-p', f'/data/local/tmp/{tag}.json')
    time.sleep(0.8)
    sh('file', 'recv', f'/data/local/tmp/{tag}.jpeg', f'{OUT}/{tag}.jpeg')
    sh('file', 'recv', f'/data/local/tmp/{tag}.json', f'{OUT}/{tag}.json')
    p = f'{OUT}/{tag}.json'
    if not os.path.exists(p):
        return []
    try:
        d = json.load(open(p, encoding='utf-8'))
    except Exception:
        return []
    res = []

    def walk(n):
        a = n.get('attributes', {})
        t = (a.get('text') or '').strip()
        typ = a.get('type', '')
        if t or typ in ('TextInput', 'TextArea', 'Button', 'Toggle'):
            res.append((typ, t, a.get('bounds', '')))
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def find(items, kw, typ=None):
    for t, tx, b in items:
        if typ and t != typ:
            continue
        if kw in tx:
            return parse_b(b)
    return None


def click(x, y):
    sh('shell', 'uitest', 'uiInput', 'click', str(x), str(y))


def click_box(box):
    click((box[0] + box[2]) // 2, (box[1] + box[3]) // 2)


def goto_countdown():
    sh('shell', 'aa', 'force-stop', PKG)
    time.sleep(1)
    sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
    time.sleep(6)
    items = dump('v_home')
    for t, tx, b in items:
        p = parse_b(b)
        if '倒数日' in tx and p and p[1] > 2400:
            click_box(p)
            break
    time.sleep(3)
    return dump('v_list')


def clear_log():
    sh('shell', 'hilog', '-r')


def grab_err():
    log = sh('shell', 'hilog', '-x', timeout=120)
    out = []
    for line in log.splitlines():
        if 'CountdownEditPage' in line or 'ANS_REMINDER' in line or ('Ans:' in line and 'Reminder' in line):
            out.append(line)
    return out


# ============ A：关闭提醒开关后新增 ============
print('=' * 56)
print('A) 关闭「到期提醒」开关后新增 —— 验证根因与规避方案')
print('=' * 56)
clear_log()
items = goto_countdown()
plus = None
for t, tx, b in items:
    p = parse_b(b)
    if p and t == 'Button' and p[0] > 800 and p[1] > 1800:
        plus = p
        break
if plus is None:
    plus = find(items, '+')
click_box(plus)
time.sleep(2.5)

items = dump('vA_form')
ti = None
for t, tx, b in items:
    if t == 'TextInput':
        ti = parse_b(b)
        break
click_box(ti)
time.sleep(1.2)
sh('shell', 'uitest', 'uiInput', 'inputText', str((ti[0] + ti[2]) // 2), str((ti[1] + ti[3]) // 2), 'A关提醒')
time.sleep(1.5)
sh('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
time.sleep(1.5)

# 找「到期提醒」那一行的 Toggle：取该行 y 范围内最右侧控件
items = dump('vA_typed')
remind_row = find(items, '到期提醒')
toggled = False
if remind_row:
    ry = (remind_row[1] + remind_row[3]) // 2
    # Toggle 通常在同一行最右
    best = None
    for t, tx, b in items:
        p = parse_b(b)
        if not p:
            continue
        cy = (p[1] + p[3]) // 2
        if abs(cy - ry) < 90 and p[0] > 900:
            if best is None or p[0] > best[0]:
                best = p
    if best:
        print(f'  关闭提醒开关 @ {best}')
        click_box(best)
        toggled = True
        time.sleep(1.5)
    else:
        # 兜底：点该行最右侧固定位置
        print(f'  兜底点击提醒行右侧 (1150,{ry})')
        click(1150, ry)
        toggled = True
        time.sleep(1.5)
print(f'  提醒开关已操作: {toggled}')

items = dump('vA_off')
save = find(items, '保存')
click_box(save)
time.sleep(3.5)
items = dump('vA_after')
txt = ' | '.join(x[1] for x in items if x[1])
on_form = '新建倒数日' in txt
print(f'  保存后仍在表单页: {"❌ 是（保存失败）" if on_form else "✅ 否（已返回=保存成功）"}')
print(f'  页面: {txt[:150]}')
errs = grab_err()
ce = [e for e in errs if 'CountdownEditPage' in e and '保存失败' in e]
print(f'  「保存失败」日志: {len(ce)} 条')
for e in ce[-2:]:
    print('   ', e[:200])

# ============ B：编辑已有事件（提醒默认开启） ============
print()
print('=' * 56)
print('B) 编辑已有事件（提醒开启）—— 是否同样报错')
print('=' * 56)
clear_log()
items = goto_countdown()
# 点第一条事件（QA 123 或 QA回归测试）
target = None
for t, tx, b in items:
    p = parse_b(b)
    if p and ('QA' in tx) and p[1] > 300 and p[1] < 2300:
        target = p
        break
if target:
    print(f'  点开事件 @ {target}')
    click_box(target)
    time.sleep(3)
    items = dump('vB_detail')
    txt = ' | '.join(x[1] for x in items if x[1])
    print(f'  详情页: {txt[:150]}')
    edit = find(items, '编辑')
    if edit:
        click_box(edit)
        time.sleep(2.5)
        items = dump('vB_form')
        txt = ' | '.join(x[1] for x in items if x[1])
        print(f'  编辑表单: {"✅ 已打开" if "编辑倒数日" in txt or "标题" in txt else "❌"}')
        save = find(items, '保存')
        if save:
            print('  直接点保存（不改内容）')
            click_box(save)
            time.sleep(3.5)
            items = dump('vB_after')
            txt = ' | '.join(x[1] for x in items if x[1])
            on_form = '编辑倒数日' in txt
            print(f'  保存后仍在表单: {"🐞 是（编辑也报错）" if on_form else "✅ 否（编辑成功）"}')
            errs = grab_err()
            ce = [e for e in errs if 'CountdownEditPage' in e and '保存失败' in e]
            print(f'  「保存失败」日志: {len(ce)} 条')
            for e in ce[-2:]:
                print('   ', e[:200])
    else:
        print('  未找到编辑入口，详情页控件:')
        for t, tx, b in items:
            if tx:
                print(f'    [{t}] {tx[:20]} {parse_b(b)}')
else:
    print('  未找到可编辑事件')

# ============ C：清理脏数据（顺带验证删除） ============
print()
print('=' * 56)
print('C) 删除脏数据 —— 顺带验证 B-4 删除功能')
print('=' * 56)
items = goto_countdown()
before = sum(1 for t, tx, b in items if 'QA回归测试' in tx)
print(f'  删除前「QA回归测试」条数: {before}')
deleted = 0
for _ in range(5):
    items = dump('vC_list')
    tgt = None
    for t, tx, b in items:
        p = parse_b(b)
        if p and 'QA回归测试' in tx and 300 < p[1] < 2300:
            tgt = p
            break
    if tgt is None:
        break
    click_box(tgt)
    time.sleep(2.5)
    items = dump('vC_detail')
    dl = find(items, '删除')
    if dl:
        click_box(dl)
        time.sleep(2)
        items = dump('vC_confirm')
        ok = find(items, '删除') or find(items, '确定')
        if ok:
            click_box(ok)
            time.sleep(2.5)
        deleted += 1
    else:
        print('  详情页无删除入口:', ' | '.join(x[1] for x in items if x[1])[:120])
        break
    time.sleep(1.5)

items = goto_countdown()
after = sum(1 for t, tx, b in items if 'QA回归测试' in tx)
print(f'  删除操作次数: {deleted}，删除后剩余: {after}')
print(f'  删除功能: {"✅ 有效" if after < before else "❌ 无效"}')
print(f'  最终列表: {" | ".join(x[1] for x in items if x[1])[:220]}')
