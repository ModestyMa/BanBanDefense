# BUG-007 手机端回归冒烟：验证 DatabaseHelper.ready() 改造未引入回归
# 覆盖：冷启动首页数据、四个 Tab 切换、倒数日列表、记账列表、番茄统计
import time, subprocess, json, os

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def tap(x, y, wait=1.6):
    sh('shell', 'uinput', '-T', '-c', str(int(x)), str(int(y)))
    time.sleep(wait)


def dump(tag):
    sh('shell', 'uitest', 'dumpLayout', '-p', f'/data/local/tmp/{tag}.json')
    time.sleep(0.8)
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
        b = a.get('bounds', '')
        if t:
            try:
                y = int(b.split('][')[0].split(',')[1])
            except Exception:
                y = 999
            if y > 120:                     # 滤掉系统状态栏
                res.append((t, b))
        for c in n.get('children', []):
            walk(c)

    walk(d)
    return res


def center(b):
    try:
        p = b.replace('][', ',').strip('[]').split(',')
        x1, y1, x2, y2 = [int(v) for v in p]
        return ((x1 + x2) // 2, (y1 + y2) // 2)
    except Exception:
        return None


def find(items, kw):
    for t, b in items:
        if kw in t:
            return (t, b)
    return None


print('=' * 62)
print('BUG-007 手机端回归冒烟（DatabaseHelper.ready 改造）')
print('=' * 62)

sh('shell', 'hilog', '-r')
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1.2)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(5)

results = {}

home = dump('s7_home')
txt = [t for t, _ in home]
print(f'\n[1] 冷启动首页 ({len(txt)} 文本):')
print('   ', ' | '.join(txt[:18]))
results['首页渲染'] = len(txt) >= 5

# 依次点四个 Tab
for name in ['番茄', '记账', '倒数日', '首页']:
    cur = dump(f's7_tmp_{name}')
    hit = find(cur, name)
    if not hit:
        print(f'\n[Tab {name}] ❌ 未找到入口')
        results[f'Tab-{name}'] = False
        continue
    c = center(hit[1])
    tap(c[0], c[1], 2.2)
    page = dump(f's7_tab_{name}')
    ptxt = [t for t, _ in page]
    print(f'\n[Tab {name}] ({len(ptxt)} 文本):')
    print('   ', ' | '.join(ptxt[:16]))
    results[f'Tab-{name}'] = len(ptxt) >= 4

# 错误日志检查
log = sh('shell', 'hilog', '-x')
errs = []
for line in log.splitlines():
    if PKG in line and (' E ' in line or '/E ' in line):
        low = line.lower()
        if any(k in line for k in ('未初始化', '加载失败', '保存失败', 'DatabaseHelper')):
            errs.append(line.strip()[:170])

print('\n' + '=' * 62)
print('[2] App 关键错误日志（未初始化/加载失败/保存失败）:')
if errs:
    for e in errs[:12]:
        print('   ❌', e)
else:
    print('   ✅ 0 条')
print('\n[3] 汇总:')
for k, v in results.items():
    print(f'   {k:12s} {"✅" if v else "❌"}')
allok = all(results.values()) and not errs
print(f'\n>>> 手机端回归 = {"✅ 无回归" if allok else "❌ 有问题，需排查"}')
print('=' * 62)
