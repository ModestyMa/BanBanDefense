# T9 探测：打印三屏控件的 text + bounds，便于后续精确点击（输入/选分类/保存）
import time, subprocess, json, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
CX, TOP, BOT = 233, 90, 380


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def dump_full(tag):
    sh('shell', 'snapshot_display', '-f', f'/data/local/tmp/{tag}.jpeg')
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
        b = a.get('bounds') or ''
        if t:
            res.append((t, b))
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def swipe(y1, y2, tag, dur=600):
    sh('shell', 'uitest', 'uiInput', 'swipe', str(CX), str(y1), str(CX), str(y2), str(dur))
    time.sleep(2.5)
    return dump_full(tag)


def center(b):
    try:
        b = b.strip('[]')
        x1, y1, x2, y2 = [int(float(v)) for v in b.split(',')]
        return ((x1 + x2) // 2, (y1 + y2) // 2)
    except Exception:
        return None


print('=== T9 三屏布局探测 ===')
sh('shell', 'aa', 'force-stop', PKG); time.sleep(1.5)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG, '-m', 'wearable'); time.sleep(6)

t0 = dump_full('t9overview'); print(f'\n### 概览屏 ({len(t0)} 控件)')
for t, b in t0:
    c = center(b)
    print(f'  {t[:24]:24} bounds={b} center={c}')

t1 = swipe(BOT, TOP, 't9quick'); print(f'\n### 快记屏 ({len(t1)} 控件)')
for t, b in t1:
    c = center(b)
    print(f'  {t[:24]:24} bounds={b} center={c}')

t2 = swipe(BOT, TOP, 't9count'); print(f'\n### 倒数日屏 ({len(t2)} 控件)')
for t, b in t2:
    c = center(b)
    print(f'  {t[:24]:24} bounds={b} center={c}')
