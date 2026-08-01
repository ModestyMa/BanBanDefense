# T21 复验：BUG-005 手表 Swiper 竖滑失效
# 验收标准：概览 →(上滑)→ 快记 →(上滑)→ 倒数日 →(下滑)→ 快记 →(下滑)→ 概览，全部切换成功
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.202:34021'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
# 手表 466x466 圆屏
CX, TOP, BOT = 233, 90, 380


def sh(*a, timeout=90):
    try:
        r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                           text=True, encoding='utf-8', errors='ignore', timeout=timeout)
        return (r.stdout or '') + (r.stderr or '')
    except Exception as e:
        return f'<ERR {e}>'


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
            res.append(t)
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def screen_of(texts):
    """根据文本特征判定当前处于哪一屏"""
    j = ' '.join(texts)
    # 快记屏特征：支出/收入方向切换 + 数字键盘 or 金额
    if ('快记' in j) or ('支出' in j and '收入' in j and ('保存' in j or '金额' in j)):
        return '快记屏'
    # 倒数日屏特征
    if '倒数日' in j or '还没有倒数日' in j or '天' == j.strip()[-1:]:
        if 'Lv.' not in j:
            return '倒数日屏'
    # 概览屏特征：宠物 Lv + 连续天数 + 今日收支
    if 'Lv.' in j or '连续' in j or '今日' in j:
        return '概览屏'
    return f'未知({j[:50]})'


def swipe(y1, y2, tag, dur=600):
    sh('shell', 'uitest', 'uiInput', 'swipe', str(CX), str(y1), str(CX), str(y2), str(dur))
    time.sleep(2.5)
    return dump(tag)


print('=' * 60)
print('T21 复验 · BUG-005 手表 Swiper 竖滑三屏切换')
print(f'设备: {SN}（466x466 圆屏）')
print('=' * 60)

# 冷启动
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1.5)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG, '-m', 'wearable')
time.sleep(6)

t0 = dump('t21_s0')
s0 = screen_of(t0)
print(f'\n[启动] 落地屏: {s0}')
print(f'  文本: {" | ".join(t0)[:150]}')

seq = []
seq.append(('启动落地', s0))

# 上滑 1：概览 → 快记
t1 = swipe(BOT, TOP, 't21_s1')
s1 = screen_of(t1)
print(f'\n[上滑1] → {s1}   {"✅ 已切换" if s1 != s0 else "❌ 未切换"}')
print(f'  文本: {" | ".join(t1)[:150]}')
seq.append(('上滑1', s1))

# 上滑 2：快记 → 倒数日
t2 = swipe(BOT, TOP, 't21_s2')
s2 = screen_of(t2)
print(f'\n[上滑2] → {s2}   {"✅ 已切换" if s2 != s1 else "❌ 未切换"}')
print(f'  文本: {" | ".join(t2)[:150]}')
seq.append(('上滑2', s2))

# 下滑 1：倒数日 → 快记
t3 = swipe(TOP, BOT, 't21_s3')
s3 = screen_of(t3)
print(f'\n[下滑1] → {s3}   {"✅ 已切换" if s3 != s2 else "❌ 未切换"}')
print(f'  文本: {" | ".join(t3)[:150]}')
seq.append(('下滑1', s3))

# 下滑 2：快记 → 概览
t4 = swipe(TOP, BOT, 't21_s4')
s4 = screen_of(t4)
print(f'\n[下滑2] → {s4}   {"✅ 已切换" if s4 != s3 else "❌ 未切换"}')
print(f'  文本: {" | ".join(t4)[:150]}')
seq.append(('下滑2', s4))

# 崩溃检查
alive = PKG in sh('shell', 'aa', 'dump', '-a')
print('\n' + '=' * 60)
print('T21 复验结论')
print('=' * 60)
for k, v in seq:
    print(f'  {k:8} → {v}')
uniq = len(set(v for _, v in seq if not v.startswith('未知')))
switched = sum(1 for i in range(1, len(seq)) if seq[i][1] != seq[i - 1][1])
print(f'\n  成功切换次数: {switched}/4')
print(f'  覆盖到的屏数: {uniq}')
print(f'  进程存活: {"✅" if alive else "❌ 崩溃"}')
verdict = switched >= 4 and uniq >= 3
print(f'\n  >>> {"🎉 T21 验收通过，BUG-005 可关闭" if verdict else "⛔ T21 未通过（竖滑仍失效）"}')
