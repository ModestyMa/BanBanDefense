# T9 E-4 补验 v8：不再执着于「关键盘」，改为键盘弹出后重新 dump
# 找「保存」按钮的实时 bounds —— 键盘弹出会压缩页面，保存按钮可能上移到键盘上方变为可点
import time, subprocess, json, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
W = H = 466

KEYS = {
    '1': (75, 218), '2': (168, 218), '3': (262, 218),
    '4': (75, 290), '5': (168, 290), '6': (262, 290), '0': (385, 290),
    '7': (75, 362), '8': (168, 362), '9': (262, 362),
}


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def snap(tag):
    sh('shell', 'snapshot_display', '-f', f'/data/local/tmp/{tag}.jpeg')
    time.sleep(0.5)
    sh('file', 'recv', f'/data/local/tmp/{tag}.jpeg', f'{OUT}/{tag}.jpeg')


def parse_bounds(b):
    """'[x1,y1][x2,y2]' -> (cx, cy, x1,y1,x2,y2)"""
    try:
        p = b.replace('][', ',').strip('[]').split(',')
        x1, y1, x2, y2 = [int(v) for v in p]
        return ((x1 + x2) // 2, (y1 + y2) // 2, x1, y1, x2, y2)
    except Exception:
        return None


def dump(tag):
    """返回 [(type, text, bounds_str, center_xy)]"""
    sh('shell', 'uitest', 'dumpLayout', '-p', f'/data/local/tmp/{tag}.json')
    time.sleep(0.6)
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
        if t:
            res.append((a.get('type', ''), t, a.get('bounds', '')))
        for c in n.get('children', []):
            walk(c)

    walk(d)
    return res


def show(tag, items):
    print(f'\n----- [{tag}] 带文本控件 {len(items)} 个 -----')
    for typ, t, b in items:
        print(f'   [{typ:12s}] {t!r:24s} @{b}')


def find(items, kw):
    for typ, t, b in items:
        if kw in t:
            return (typ, t, b)
    return None


def tap(x, y, wait=1.2, note=''):
    print(f'   tap({x},{y}) {note}')
    sh('shell', 'uinput', '-T', '-c', str(int(x)), str(int(y)))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, ms=500, wait=1.5):
    sh('shell', 'uinput', '-T', '-m', str(x1), str(y1), str(x2), str(y2), str(ms))
    time.sleep(wait)


print('=' * 60)
print('T9 E-4 v8：键盘遮挡下寻找保存按钮实时坐标')
print('=' * 60)

# 0) 冷启动
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(4)

# 1) 记录概览屏初始余额
ov0 = dump('v8_00_overview')
show('概览屏(初始)', ov0)

# 2) 上滑到快记屏
swipe(233, 380, 233, 90, 500, 1.8)
qa0 = dump('v8_01_quickadd')
show('快记屏(未弹键盘)', qa0)
save0 = find(qa0, '保存')
print(f'\n>> 未弹键盘时「保存」: {save0}')

# 3) 点金额输入框弹键盘
amt = find(qa0, '¥')
if amt:
    c = parse_bounds(amt[2])
    tx, ty = (c[0] + 60, c[1]) if c else (233, 130)
else:
    tx, ty = 233, 130
tap(tx, ty, 2.0, '点金额输入框')
snap('v8_02_kbd')

# 4) 坐标键入 12
for ch in '12':
    x, y = KEYS[ch]
    tap(x, y, 0.8, f'键入 {ch}')

# 5) 键盘弹出状态下重新 dump —— 关键一步
kb = dump('v8_03_with_kbd')
show('快记屏(键盘弹出中)', kb)
amt_now = find(kb, '12')
print(f'\n>> 金额录入结果: {amt_now}')

save1 = find(kb, '保存')
print(f'>> 键盘弹出时「保存」: {save1}')

clicked = False
if save1:
    c = parse_bounds(save1[2])
    if c:
        cx, cy, x1, y1, x2, y2 = c
        print(f'   保存按钮 bounds=({x1},{y1})-({x2},{y2}) 中心=({cx},{cy})')
        if 0 <= cx <= W and 0 <= cy <= H:
            tap(cx, cy, 2.5, '<<< 点击保存按钮')
            clicked = True
        else:
            print('   !! 中心点在屏幕外，不可点')
else:
    print('   !! dump 中找不到保存按钮（被键盘覆盖层挡住）')

snap('v8_04_after_save')

# 6) 回概览屏核对
after = dump('v8_05_after')
show('保存后当前屏', after)
swipe(233, 90, 233, 380, 500, 1.8)
swipe(233, 90, 233, 380, 500, 1.8)
ov1 = dump('v8_06_overview_after')
show('概览屏(保存后)', ov1)

print('\n' + '=' * 60)
print(f'结论：点击保存 = {clicked}')
t0 = [t for _, t, _ in ov0]
t1 = [t for _, t, _ in ov1]
print(f'概览屏文本变化: {"是 ✅" if t0 != t1 else "否 ❌"}')
print(f'  before: {t0}')
print(f'  after : {t1}')
print('=' * 60)
