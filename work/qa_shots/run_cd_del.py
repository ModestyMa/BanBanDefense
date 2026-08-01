# 精确验证删除功能：进详情→点删除→在弹窗中精确找「删除」按钮
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


def find(items, kw):
    for t, tx, b in items:
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
    items = dump('dl_home')
    for t, tx, b in items:
        p = parse_b(b)
        if '倒数日' in tx and p and p[1] > 2400:
            click_box(p)
            break
    time.sleep(3)
    return dump('dl_list')


print('=== 精确删除验证 ===\n')

items = goto_countdown()
before = sum(1 for t, tx, b in items if 'QA回归测试' in tx)
print(f'[0] 删除前 QA回归测试 条数: {before}')

# 进第一条 QA回归测试 详情
tgt = None
for t, tx, b in items:
    p = parse_b(b)
    if p and 'QA回归测试' in tx and 300 < p[1] < 2300:
        tgt = p
        break
if not tgt:
    print('!! 未找到目标事件')
    sys.exit(1)

click_box(tgt)
time.sleep(2.5)
items = dump('dl_detail')
print(f'[1] 详情页: {"✅" if "详情" in (x[1] for x in items) else "❌"}')

# 点底部「删除这个日子」
del_btn = find(items, '删除这个日子')
if del_btn:
    print(f'[2] 点删除 {del_btn}')
    click_box(del_btn)
else:
    print('[2] !! 未找到「删除这个日子」')
    # 打印所有控件
    for t, tx, b in items:
        p = parse_b(b)
        if p and p[1] > 2000:
            print(f'     [{t}] {tx} {p}')
time.sleep(2.5)

# 弹窗出现：dump 并打印全部控件（含弹窗内）
items = dump('dl_dialog')
print(f'\n[3] 弹窗后全部文本:')
for t, tx, b in items:
    p = parse_b(b)
    if tx:
        print(f'     [{t:10}] {tx[:24]:26} ({p})')

# 找弹窗内的「删除」按钮（红色文字）
del_confirm = None
cancel_btn = None
for t, tx, b in items:
    p = parse_b(b)
    if not p:
        continue
    # 弹窗通常居中，y 在 1000~1800
    if '删除' == tx.strip() and 800 < (p[1]+p[3])/2 < 2000:
        del_confirm = p
    if '取消' == tx.strip() and 800 < (p[1]+p[3])/2 < 2000:
        cancel_btn = p

print(f'\n[4] 弹窗「删除」按钮: {del_confirm}')
print(f'    「取消」按钮: {cancel_btn}')

if del_confirm:
    print(f'[5] 点弹窗「删除」{del_confirm}')
    click_box(del_confirm)
elif cancel_btn:
    # 兜底：删除在取消右侧
    cx = cancel_btn[2] + 120
    cy = (cancel_btn[1] + cancel_btn[3]) // 2
    print(f'[5] 兜底点取消右侧 ({cx},{cy})')
    click(cx, cy)
else:
    print('[5] !! 无法定位弹窗按钮，用固定坐标兜底')
    click(950, 1400)  # 删除按钮大概位置

time.sleep(3)
items = dump('dl_after_del')
txt = ' | '.join(x[1] for x in items if x[1])
still_dialog = any('删除' in x[1] and '?' in x[1] for x in items)
print(f'\n[6] 弹窗仍显示: {"是" if still_dialog else "否（已关闭）"}')
print(f'    页面: {txt[:150]}')

# 冷启动看真实数据
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(6)
items = dump('dl_home2')
tab = None
for t, tx, b in items:
    p = parse_b(b)
    if '倒数日' in tx and p and p[1] > 2400:
        tab = p
        break
if tab:
    click_box(tab)
time.sleep(3)
items = dump('dl_list2')
after = sum(1 for t, tx, b in items if 'QA回归测试' in tx)
print(f'\n[7] 删除后 QA回归测试 条数: {after} (之前 {before})')
print(f'[8] 删除功能: {"🐞 无效" if after >= before else "✅ 有效"}')
print(f'    最终列表: {" | ".join(x[1] for x in items if x[1])[:250]}')
