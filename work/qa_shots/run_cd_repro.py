# 倒数日新增/编辑报错复现 + hilog 抓错
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
        if t or typ in ('TextInput', 'TextArea', 'Button'):
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


print(f'=== 设备 {SN} 倒数日增改报错复现 ===\n')

# 0) 清日志缓冲 + 冷启动
sh('shell', 'hilog', '-r')
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(6)

# 1) 进倒数日 Tab
items = dump('cd0_home')
tab = None
for t, tx, b in items:
    p = parse_b(b)
    if '倒数日' in tx and p and p[1] > 2400:
        tab = p
        break
if tab:
    click_box(tab)
    print(f'[1] 点倒数日 Tab {tab}')
else:
    print('[1] !! 未找到倒数日 Tab，尝试固定坐标')
    click(490, 2680)
time.sleep(2.5)

items = dump('cd1_list')
print('[2] 倒数日页文本:', ' | '.join(x[1] for x in items if x[1])[:160])

# 2) 找 + 按钮（右上或右下悬浮）
plus = None
for t, tx, b in items:
    p = parse_b(b)
    if not p:
        continue
    if tx.strip() in ('+', '＋') or ('新建' in tx) or ('添加' in tx):
        plus = p
        break
if plus is None:
    # 悬浮按钮通常在右下角
    for t, tx, b in items:
        p = parse_b(b)
        if p and t == 'Button' and p[0] > 800 and p[1] > 1800:
            plus = p
            break
if plus:
    print(f'[3] 点 + 按钮 {plus}')
    click_box(plus)
else:
    print('[3] !! 未定位 +，用右上角兜底')
    click(1150, 300)
time.sleep(2.5)

items = dump('cd2_form')
has_form = any('标题' in x[1] or '目标日期' in x[1] for x in items)
print(f'[4] 编辑表单打开: {"✅" if has_form else "❌"}')
if not has_form:
    print('    当前文本:', ' | '.join(x[1] for x in items if x[1])[:200])
    sys.exit(1)

# 3) 点标题输入框 + 输入
ti = None
for t, tx, b in items:
    if t == 'TextInput':
        ti = parse_b(b)
        break
if ti:
    click_box(ti)
    time.sleep(1.2)
    sh('shell', 'uitest', 'uiInput', 'inputText', str((ti[0] + ti[2]) // 2), str((ti[1] + ti[3]) // 2), 'QA回归测试')
    print('[5] 已输入标题 QA回归测试')
    time.sleep(1.5)

# 4) 收键盘（Back 键）
sh('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
time.sleep(1.5)
items = dump('cd3_typed')
title_ok = any('QA回归测试' in x[1] for x in items)
print(f'[6] 标题已写入: {"✅" if title_ok else "❌"}')

# 5) 点保存
save = find(items, '保存')
if save is None:
    save = find(items, '确定')
if save:
    print(f'[7] 点保存 {save}')
    click_box(save)
else:
    print('[7] !! 未找到保存按钮，当前控件:')
    for t, tx, b in items:
        if t == 'Button' or '保存' in tx:
            print(f'     [{t}] {tx} {parse_b(b)}')
time.sleep(3.5)

items = dump('cd4_after_save')
alltext = ' | '.join(x[1] for x in items if x[1])
print(f'[8] 保存后页面: {alltext[:220]}')
saved_ok = 'QA回归测试' in alltext and not any('标题' == x[1] for x in items)
fail_toast = '失败' in alltext
print(f'[9] 列表出现新事件: {"✅" if "QA回归测试" in alltext else "❌"}')
print(f'[10] 出现失败提示: {"🐞 是" if fail_toast else "否"}')

# 6) 抓日志
print('\n=== hilog 错误日志 ===')
log = sh('shell', 'hilog', '-x', timeout=120)
keys = ('ReminderService', 'CountdownEditPage', 'CountdownRepository',
        'publishReminder', 'reminder', 'Countdown', '保存失败')
hits = []
for line in log.splitlines():
    low = line.lower()
    if any(k.lower() in low for k in keys) or ' E ' in line and 'banban' in low:
        hits.append(line)
for l in hits[-60:]:
    print('  ', l[:230])
if not hits:
    print('   (无匹配日志)')

open(f'{OUT}/cd_hilog.txt', 'w', encoding='utf-8').write(log)
print(f'\n完整日志已存 {OUT}/cd_hilog.txt')
