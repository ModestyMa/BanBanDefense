# T9 E-4 v9：v8 已定位真因 —— 手表 IME 是独立窗口，数字停在 IME 的 RichEditor 预览框，
# 未回填 App。本脚本 dump IME 窗口的【全部节点】（含无 text 的图标按钮），找确认/回填键。
import time, subprocess, json, os

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'

KEYS = {'1': (75, 218), '2': (168, 218)}


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def tap(x, y, wait=1.2, note=''):
    print(f'   tap({x},{y}) {note}')
    sh('shell', 'uinput', '-T', '-c', str(int(x)), str(int(y)))
    time.sleep(wait)


def swipe(x1, y1, x2, y2, ms=500, wait=1.5):
    sh('shell', 'uinput', '-T', '-m', str(x1), str(y1), str(x2), str(y2), str(ms))
    time.sleep(wait)


def dump_all(tag):
    """dump 全部节点：type / text / bounds / clickable / id / description"""
    sh('shell', 'uitest', 'dumpLayout', '-p', f'/data/local/tmp/{tag}.json')
    time.sleep(0.7)
    sh('file', 'recv', f'/data/local/tmp/{tag}.json', f'{OUT}/{tag}.json')
    p = f'{OUT}/{tag}.json'
    if not os.path.exists(p):
        return []
    try:
        d = json.load(open(p, encoding='utf-8'))
    except Exception as e:
        print('   parse err', e)
        return []
    res = []

    def walk(n, depth=0):
        a = n.get('attributes', {})
        res.append({
            'depth': depth,
            'type': a.get('type', ''),
            'text': (a.get('text') or '').strip(),
            'bounds': a.get('bounds', ''),
            'clickable': a.get('clickable', ''),
            'id': a.get('id', ''),
            'desc': (a.get('description') or '').strip(),
            'key': (a.get('key') or '').strip(),
        })
        for c in n.get('children', []):
            walk(c, depth + 1)

    walk(d)
    return res


def show_all(tag, nodes, only_clickable=False):
    print(f'\n----- [{tag}] 节点 {len(nodes)} 个 -----')
    for n in nodes:
        if only_clickable and n['clickable'] != 'true':
            continue
        ind = '  ' * min(n['depth'], 6)
        extra = []
        if n['text']:
            extra.append(f"text={n['text']!r}")
        if n['desc']:
            extra.append(f"desc={n['desc']!r}")
        if n['key']:
            extra.append(f"key={n['key']!r}")
        if n['id']:
            extra.append(f"id={n['id']}")
        if n['clickable'] == 'true':
            extra.append('CLICKABLE')
        print(f"{ind}[{n['type']}] @{n['bounds']} {' '.join(extra)}")


print('=' * 64)
print('T9 E-4 v9：解剖手表 IME 窗口，寻找回填/确认键')
print('=' * 64)

sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(4)

swipe(233, 380, 233, 90, 500, 1.8)   # -> 快记屏
tap(119, 126, 2.2, '点金额输入框弹 IME')

for ch in '12':
    tap(*KEYS[ch], wait=0.7, note=f'键入 {ch}')

nodes = dump_all('v9_ime_full')
show_all('IME 窗口全节点', nodes)
print('\n>>>>> 仅 clickable 节点 <<<<<')
show_all('clickable', nodes, only_clickable=True)
print('=' * 64)
