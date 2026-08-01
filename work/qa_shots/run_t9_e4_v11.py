# T9 E-4 诊断 v11：金额已回填但保存无效 —— 查保存按钮 enabled 状态 + 抓 hilog
# 疑点：canSave() = isValidAmount(amountText) && vm.defaultAccountId > 0
#       概览屏全 0 数据，怀疑手表端 defaultAccountId <= 0（无默认账户）
import time, subprocess, json, os

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
IME_OK = (334, 72)
KEYS = {'1': (62, 223), '2': (176, 223)}


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def tap(x, y, wait=1.2, note=''):
    if note:
        print(f'   tap({x},{y}) {note}')
    sh('shell', 'uinput', '-T', '-c', str(int(x)), str(int(y)))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, ms=500, wait=1.6):
    sh('shell', 'uinput', '-T', '-m', str(x1), str(y1), str(x2), str(y2), str(ms))
    time.sleep(wait)


def dump_nodes(tag):
    sh('shell', 'uitest', 'dumpLayout', '-p', f'/data/local/tmp/{tag}.json')
    time.sleep(0.7)
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
        res.append(a)
        for c in n.get('children', []):
            walk(c)

    walk(d)
    return res


print('=' * 64)
print('T9 E-4 诊断 v11：保存按钮为何无效')
print('=' * 64)

# 清日志
sh('shell', 'hilog', '-r')
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(4.5)

swipe(233, 380, 233, 90, 500, 2.0)
tap(119, 126, 2.2, '点金额输入框')
for ch in '12':
    tap(*KEYS[ch], wait=0.7, note=f'键入 {ch}')
tap(*IME_OK, wait=2.2, note='IME 确认回填')

nodes = dump_nodes('v11_state')
print('\n----- 保存按钮完整属性 -----')
for a in nodes:
    if a.get('type') == 'Button' or '保存' in (a.get('text') or ''):
        for k in ('type', 'text', 'bounds', 'enabled', 'clickable', 'focused',
                  'visible', 'checkable', 'selected', 'id', 'key'):
            if k in a:
                print(f'   {k:12s}= {a[k]}')
        print('   ---')

print('\n----- TextInput 属性 -----')
for a in nodes:
    if a.get('type') == 'TextInput':
        for k in ('type', 'text', 'bounds', 'enabled', 'clickable'):
            if k in a:
                print(f'   {k:12s}= {a[k]}')

# 点保存
tap(233, 400, 3.0, '<<< 点保存')

print('\n----- hilog: WatchQuickAddPage / WatchViewModel / Repository -----')
log = sh('shell', 'hilog', '-x')
hit = 0
for line in log.splitlines():
    if any(k in line for k in ('WatchQuickAdd', 'WatchViewModel', 'watchVM',
                               'AccountRepository', 'TransactionRepository',
                               'PetEngine', 'defaultAccount', 'banban')):
        print('  ', line.strip()[:200])
        hit += 1
        if hit > 60:
            print('   ...(截断)')
            break
if hit == 0:
    print('   (无相关日志)')
print('=' * 64)
