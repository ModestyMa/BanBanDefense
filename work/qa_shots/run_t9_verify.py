# T9 补验 v7：坐标键入整数12→下滑手势关键盘→保存→概览(-12.00)+倒数日
# 新尝试：在键盘区域执行下滑手势（很多IME支持下滑关闭）
import time, subprocess, json, os, sys, re

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'

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


def dump(tag):
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
        b = a.get('bounds') or ''
        if t:
            res.append((t, b))
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def center(b):
    try:
        b = b.strip('[]')
        x1, y1, x2, y2 = [int(float(v)) for v in b.split(',')]
        return ((x1 + x2) // 2, (y1 + y2) // 2)
    except Exception:
        return None


def click_text(sub):
    items = dump('t9click')
    for t, b in items:
        if sub in t:
            c = center(b)
            if c:
                sh('shell', 'uitest', 'uiInput', 'click', str(c[0]), str(c[1]))
                time.sleep(0.6)
                return c
    return None


def click_xy(x, y):
    sh('shell', 'uitest', 'uiInput', 'click', str(x), str(y))
    time.sleep(0.5)


def swipe_xy(x, y1, y2, dur=600):
    sh('shell', 'uitest', 'uiInput', 'swipe', str(x), str(y1), str(x), str(y2), str(dur))
    time.sleep(2.0)


def swipe(y1, y2, tag, dur=600):
    sh('shell', 'uitest', 'uiInput', 'swipe', '233', str(y1), '233', str(y2), str(dur))
    time.sleep(2.5)
    return dump(tag)


def expense_of(items):
    for t, _ in items:
        m = re.search(r'-\d+\.\d{2}', t)
        if m:
            return m.group(0)
    return None


print('=== T9 补验 v7（下滑关键盘）===')
sh('shell', 'aa', 'force-stop', PKG); time.sleep(1.5)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG, '-m', 'wearable'); time.sleep(6)

qk = swipe(380, 90, 't9qk'); snap('t9qk')
print(f'[快记屏] 控件={len(qk)} : {[t for t,_ in qk]}')

# 聚焦金额字段
click_xy(200, 138)
time.sleep(2.0)
snap('t9kb')

# 输入整数 12
for ch in ['1', '2']:
    if ch in KEYS:
        x, y = KEYS[ch]
        click_xy(x, y)
        print(f'  按键 {ch} @ ({x},{y})')
time.sleep(0.5)
snap('t9typed')

# 方法A：在键盘中心区域下滑（模拟手指下滑关闭IME）
print('[尝试] 键盘区下滑手势关闭...')
swipe_xy(233, 350, 100, 800)  # 从键盘中部向上滑到页面顶部

post = dump('t9post'); snap('t9post')
kb_gone = all(len(t) > 2 or not t.isdigit() for t, _ in post)
print(f'[下滑后] 控件={len(post)} 键盘消失={kb_gone} : {[t for t,_ in post][:10]}')

if not kb_gone:
    # 方法B：点击屏幕最顶部边缘（状态栏区域）
    print('[尝试B] 点击状态栏区域...')
    click_xy(233, 10)
    time.sleep(1.5)
    post = dump('t9post2'); snap('t9post2')
    kb_gone = all(len(t) > 2 or not t.isdigit() for t, _ in post)
    print(f'[点顶栏后] 键盘消失={kb_gone} : {[t for t,_ in post][:10]}')

if not kb_gone:
    # 方法C：长按页面空白区
    print('[尝试C] 长按页面标题区...')
    sh('shell', 'uitest', 'uiInput', 'longPress', '120', '55')
    time.sleep(1.5)
    post = dump('t9post3'); snap('t9post3')
    kb_gone = all(len(t) > 2 or not t.isdigit() for t, _ in post)
    print(f'[长按后] 键盘消失={kb_gone} : {[t for t,_ in post][:10]}')

# 点保存（如果键盘消失了）
if kb_gone:
    c_save = click_text('保存')
    print(f'[点保存] {c_save}')
else:
    print('[⚠️] 键盘未关闭，跳过保存步骤')
    c_save = None

time.sleep(2.5)
snap('t9save')

# 回概览
swipe(90, 380, 't9back'); snap('t9ov1')
ov1 = dump('t9ov1')
exp1 = expense_of(ov1)
print(f'[概览支出] = {exp1} (期望 -12.00) : {[t for t,_ in ov1][:6]}')

# E-6 倒数日
swipe(380, 90, 't9c1')
cd = swipe(380, 90, 't9c2'); snap('t9cd')
cd_text = [t for t, _ in cd]
print(f'[倒数日] {cd_text}')

save_ok = (exp1 == '-12.00')
e6_ok = any('倒数日' in t for t in cd_text)
print('\n=== 结论 ===')
print(f'  E-4 保存成功(=-12.00): {"✅" if save_ok else "❌"}')
print(f'  E-6 倒数日显示: {"✅" if e6_ok else "❌"}')
if not save_ok:
    print(f'  ⚠️ 根因: {"键盘无法关闭" if not kb_gone else "保存失败"} — 建议圣人手动验证快记保存流程')
print(f'  >>> {"🎉 T9 通过" if save_ok and e6_ok else "⛔ 需手动验证或排查"}')
