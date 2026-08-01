# T9 E-4 终验 v10：真因已破 —— 手表 IME 独立窗口，须点 inputBtnOkArea(334,72) 回填+关闭
# 完整链路：弹IME -> 键入12 -> 确认回填 -> 选分类"交通" -> 点保存 -> 回概览验 -12.00
import time, subprocess, json, os

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'

# IME 面板坐标（v9 dump 实测）
IME_OK = (334, 72)                      # inputBtnOkArea 确认回填键
KEYS = {
    '1': (62, 223), '2': (176, 223), '3': (290, 223), '.': (404, 223),
    '4': (62, 285), '5': (176, 285), '6': (290, 285), '0': (404, 285),
    '7': (62, 347), '8': (176, 347), '9': (290, 347),
}


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


def snap(tag):
    sh('shell', 'snapshot_display', '-f', f'/data/local/tmp/{tag}.jpeg')
    time.sleep(0.5)
    sh('file', 'recv', f'/data/local/tmp/{tag}.jpeg', f'{OUT}/{tag}.jpeg')


def dump(tag):
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
        t = (a.get('text') or '').strip()
        if t:
            res.append((a.get('type', ''), t, a.get('bounds', '')))
        for c in n.get('children', []):
            walk(c)

    walk(d)
    return res


def show(tag, items):
    print(f'\n----- [{tag}] {len(items)} 个带文本控件 -----')
    for typ, t, b in items:
        print(f'   [{typ:12s}] {t!r:22s} @{b}')


def find(items, kw):
    for typ, t, b in items:
        if kw in t:
            return (typ, t, b)
    return None


def center(b):
    try:
        p = b.replace('][', ',').strip('[]').split(',')
        x1, y1, x2, y2 = [int(v) for v in p]
        return ((x1 + x2) // 2, (y1 + y2) // 2)
    except Exception:
        return None


print('=' * 64)
print('T9 E-4 终验 v10：手表快记 保存链路')
print('=' * 64)

sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(4.5)

# 1) 概览屏基线
ov0 = dump('e4_00_ov_before')
show('概览屏(保存前)', ov0)
base = [t for _, t, _ in ov0]

# 2) 上滑到快记屏
swipe(233, 380, 233, 90, 500, 2.0)
qa = dump('e4_01_quickadd')
show('快记屏', qa)
if not find(qa, '保存'):
    print('!! 未进入快记屏，中止')
    raise SystemExit(1)
save_xy = center(find(qa, '保存')[2])

# 3) 弹 IME 输入 12
tap(119, 126, 2.2, '点金额输入框')
for ch in '12':
    tap(*KEYS[ch], wait=0.7, note=f'键入 {ch}')
snap('e4_02_ime')
tap(*IME_OK, wait=2.2, note='<<< 点 IME 确认键 inputBtnOkArea 回填')
snap('e4_03_after_ok')

# 4) 校验是否已回到 App 且金额回填
back_app = dump('e4_04_back_app')
show('确认后当前窗口', back_app)
has_save = find(back_app, '保存')
amount_ok = find(back_app, '12')
print(f'\n>> IME 已关闭(App保存按钮可见): {"✅" if has_save else "❌"}')
print(f'>> 金额回填 App: {amount_ok}')

if not has_save:
    print('!! IME 未关闭，中止')
    raise SystemExit(1)

# 5) 选分类「交通」
cat = find(back_app, '交通')
if cat:
    cx, cy = center(cat[2])
    tap(cx, cy, 1.2, '选分类 交通')

# 6) 点保存
sv = find(dump('e4_05_pre_save'), '保存')
sxy = center(sv[2]) if sv else save_xy
tap(*sxy, wait=2.8, note='<<< 点保存')
snap('e4_06_saved')
after_save = dump('e4_06_saved')
show('保存后快记屏', after_save)

# 7) 回概览屏核对
swipe(233, 90, 233, 380, 500, 2.0)
ov1 = dump('e4_07_ov_after')
show('概览屏(保存后)', ov1)
snap('e4_08_ov_after')
now = [t for _, t, _ in ov1]

print('\n' + '=' * 64)
exp = [t for t in now if t.startswith('-')]
print(f'概览屏 before: {base}')
print(f'概览屏 after : {now}')
print(f'今日支出项    : {exp}')
ok = any('12.00' in t for t in now)
print(f'\nE-4 快记保存 = {"✅ 通过（今日支出出现 -12.00）" if ok else "❌ 未见 -12.00"}')
print('=' * 64)
