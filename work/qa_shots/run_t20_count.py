# T20 计数复核：滚动整个倒数日列表，去重统计 T20V 条目（排除可视区截断导致的假阴性）
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'


def sh(*a, timeout=90):
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
        if t:
            res.append((t, parse_b(a.get('bounds', ''))))
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(6)
items = dump('cnt_home')
for t, p in items:
    if '倒数日' in t and p and p[1] > 2400:
        sh('shell', 'uitest', 'uiInput', 'click', str((p[0] + p[2]) // 2), str((p[1] + p[3]) // 2))
        break
time.sleep(3)

print('=' * 56)
print('T20 计数复核 · 滚动全列表去重统计')
print('=' * 56)

seen = set()
all_titles = []
for i in range(8):
    items = dump(f'cnt_{i}')
    page = []
    for t, p in items:
        if p and 300 < p[1] < 2400:
            page.append(t)
            if t not in seen:
                seen.add(t)
                all_titles.append(t)
    print(f'  第{i+1}屏可见: {" | ".join(page)[:160]}')
    # 上滑翻页
    sh('shell', 'uitest', 'uiInput', 'swipe', '600', '2000', '600', '900', '600')
    time.sleep(2)

t20 = sorted([t for t in seen if t.startswith('T20V')])
print()
print(f'  全列表去重条目数: {len(seen)}')
print(f'  T20V 条目: {t20}  → {len(t20)} 条')
print(f'  判定: {"✅ 精确 5 条，无重复污染" if len(t20) == 5 else f"⚠️ 实得 {len(t20)} 条"}')
print()
print(f'  全部条目: {" | ".join(sorted(seen))[:400]}')
