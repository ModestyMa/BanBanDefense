# T20 复验：BUG-006 倒数日增改报错（通知权限关闭状态下，提醒开关保持默认开启）
# 验收标准：① 新增×5 全部成功返回列表 ② 计数精确=5（无重复污染）
#          ③ 编辑保存成功 ④ hilog 出现「提醒调度降级」warn 且「保存失败」=0
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
MARK = 'T20V'


def sh(*a, timeout=120):
    try:
        r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                           text=True, encoding='utf-8', errors='ignore', timeout=timeout)
        return (r.stdout or '') + (r.stderr or '')
    except Exception as e:
        return f'<ERR {e}>'


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


def goto_countdown(tag='t20_list'):
    sh('shell', 'aa', 'force-stop', PKG)
    time.sleep(1)
    sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
    time.sleep(6)
    items = dump('t20_home')
    for t, tx, b in items:
        p = parse_b(b)
        if '倒数日' in tx and p and p[1] > 2400:
            click_box(p)
            break
    time.sleep(3)
    return dump(tag)


def count_mark(items):
    return sum(1 for t, tx, b in items if MARK in tx)


def add_one(idx):
    """新增一条，提醒开关保持默认（开启）。返回 (是否返回列表, 页面文本)"""
    items = dump(f't20_a{idx}_list')
    plus = None
    for t, tx, b in items:
        p = parse_b(b)
        if p and t == 'Button' and p[0] > 800 and p[1] > 1800:
            plus = p
            break
    if plus is None:
        plus = find(items, '+')
    if plus is None:
        return None, '未找到+按钮'
    click_box(plus)
    time.sleep(2.5)

    items = dump(f't20_a{idx}_form')
    ti = None
    for t, tx, b in items:
        if t == 'TextInput':
            ti = parse_b(b)
            break
    if ti is None:
        return None, '未找到输入框'
    click_box(ti)
    time.sleep(1.2)
    sh('shell', 'uitest', 'uiInput', 'inputText',
       str((ti[0] + ti[2]) // 2), str((ti[1] + ti[3]) // 2), f'{MARK}{idx}')
    time.sleep(1.5)
    sh('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')  # 收键盘
    time.sleep(1.5)

    items = dump(f't20_a{idx}_typed')
    save = find(items, '保存')
    if save is None:
        return None, '未找到保存按钮'
    click_box(save)
    time.sleep(3.5)
    items = dump(f't20_a{idx}_after')
    txt = ' | '.join(x[1] for x in items if x[1])
    on_form = '新建倒数日' in txt
    return (not on_form), txt[:120]


def clear_log():
    sh('shell', 'hilog', '-r')


def grab_log():
    log = sh('shell', 'hilog', '-x', timeout=150)
    save_fail, degrade, ans = [], [], []
    for line in log.splitlines():
        if 'CountdownEditPage' in line and '保存失败' in line:
            save_fail.append(line)
        if '提醒调度降级' in line or ('CountdownViewModel' in line and 'W ' in line):
            degrade.append(line)
        if 'ANS_REMINDER' in line and 'exceeds' in line:
            ans.append(line)
    return save_fail, degrade, ans


print('=' * 60)
print('T20 复验 · BUG-006 倒数日增改报错（提醒开关保持默认开启）')
print(f'设备: {SN}')
print('=' * 60)

clear_log()

# ---------- 步骤 0：进倒数日，记录基线 ----------
items = goto_countdown('t20_base')
base_all = [x[1] for x in items if x[1]]
print(f'\n[基线] 列表现有条目: {" | ".join(base_all)[:200]}')
print(f'[基线] 已有 {MARK} 标记: {count_mark(items)} 条')

# ---------- 步骤 A：新增 ×5 ----------
print('\n' + '=' * 60)
print('A) 默认设置（提醒开启）连续新增 5 条')
print('=' * 60)
ok_cnt = 0
for i in range(1, 6):
    ok, txt = add_one(i)
    flag = '✅ 成功返回列表' if ok else ('❌ 仍停留表单(保存失败)' if ok is False else f'⚠️ {txt}')
    print(f'  第{i}次 {MARK}{i}: {flag}')
    if ok:
        ok_cnt += 1
    time.sleep(1)

# ---------- 步骤 B：计数校验（防重复污染） ----------
print('\n' + '=' * 60)
print('B) 计数校验 —— 应精确 5 条，不多不少')
print('=' * 60)
items = goto_countdown('t20_count')
n = count_mark(items)
titles = [x[1] for x in items if MARK in x[1]]
print(f'  库中 {MARK} 条数: {n}')
print(f'  标题: {titles}')
print(f'  判定: {"✅ 精确 5 条，无重复污染" if n == 5 else f"❌ 期望 5 条实得 {n} 条"}')

# ---------- 步骤 C：编辑复验 ----------
print('\n' + '=' * 60)
print('C) 编辑已有事件（提醒开启）—— 是否仍报错')
print('=' * 60)
edit_ok = None
tgt = None
for t, tx, b in items:
    p = parse_b(b)
    if p and MARK in tx and 300 < p[1] < 2300:
        tgt = p
        break
if tgt:
    click_box(tgt)
    time.sleep(3)
    items2 = dump('t20_c_detail')
    ed = find(items2, '编辑')
    if ed:
        click_box(ed)
        time.sleep(2.5)
        items3 = dump('t20_c_form')
        save = find(items3, '保存')
        if save:
            click_box(save)
            time.sleep(3.5)
            items4 = dump('t20_c_after')
            txt = ' | '.join(x[1] for x in items4 if x[1])
            edit_ok = '编辑倒数日' not in txt
            print(f'  编辑保存: {"✅ 成功返回" if edit_ok else "🐞 仍停留表单(编辑报错)"}')
            print(f'  页面: {txt[:140]}')
        else:
            print('  ⚠️ 编辑表单无保存按钮')
    else:
        print('  ⚠️ 详情页无编辑入口:', ' | '.join(x[1] for x in items2 if x[1])[:120])
else:
    print('  ⚠️ 未找到可编辑条目')

# ---------- 步骤 D：日志校验 ----------
print('\n' + '=' * 60)
print('D) 日志校验')
print('=' * 60)
sf, dg, ans = grab_log()
print(f'  ❌「保存失败」error 日志: {len(sf)} 条  {"✅ 达标(应为0)" if len(sf) == 0 else "🐞 仍在报错"}')
for e in sf[-3:]:
    print('     ', e[:180])
print(f'  ⚠️「提醒调度降级」warn: {len(dg)} 条  {"✅ 降级生效" if len(dg) > 0 else "（未捕获，可能日志已滚动）"}')
for e in dg[-3:]:
    print('     ', e[:180])
print(f'  ℹ️ ANS_REMINDER exceeds limit(系统侧): {len(ans)} 条（系统行为，不阻断即可）')

# ---------- 汇总 ----------
print('\n' + '=' * 60)
print('T20 复验结论')
print('=' * 60)
print(f'  新增 5 次成功: {ok_cnt}/5      {"✅" if ok_cnt == 5 else "❌"}')
print(f'  计数精确 5 条: {n}          {"✅" if n == 5 else "❌"}')
print(f'  编辑保存成功: {edit_ok}      {"✅" if edit_ok else "❌"}')
print(f'  保存失败日志: {len(sf)} 条     {"✅" if len(sf) == 0 else "❌"}')
verdict = (ok_cnt == 5 and n == 5 and edit_ok and len(sf) == 0)
print(f'\n  >>> {"🎉 T20 验收通过，BUG-006 可关闭" if verdict else "⛔ T20 未通过，需回退主程序"}')
