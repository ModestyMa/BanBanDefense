# T21 排查②：键盘态下，从键盘上方(y=220)起滑，验证 Swiper 能否继续切走
# 若能切走 => 确认是「软键盘吃掉手势」（键盘挡在底部，落点 380 在键盘内）
# 若仍卡 => nestedScroll 仍拦截（真没修好）
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


def dump(tag):
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
        if t:
            res.append(t)
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def screen_of(texts):
    j = ' '.join(texts)
    if 'Lv.' in j or '连续' in j or '今日' in j:
        return '概览屏'
    if '倒数日' in j or '还没有倒数日' in j:
        return '倒数日屏'
    if '快记' in j or '保存' in j or '金额' in j:
        return '快记屏'
    if any(ch.isdigit() for ch in j) and ('@' in j or '.' in j):
        return '数字键盘态'
    return f'未知({j[:40]})'


def swipe(y1, y2, tag, dur=600):
    sh('shell', 'uitest', 'uiInput', 'swipe', str(CX), str(y1), str(CX), str(y2), str(dur))
    time.sleep(2.5)
    return dump(tag)


print('=== T21 排查②：键盘上方起滑 ===')
sh('shell', 'aa', 'force-stop', PKG); time.sleep(1.5)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG, '-m', 'wearable'); time.sleep(6)

t0 = dump('p2_s0'); s0 = screen_of(t0)
print(f'[启动] {s0}')

# 先到底部起滑进快记（触发键盘）
t1 = swipe(BOT, TOP, 'p2_s1'); s1 = screen_of(t1)
print(f'[上滑(380→90)→] {s1}')

# 键盘态下，从键盘上方 y=220 起滑
t2 = swipe(220, TOP, 'p2_s2'); s2 = screen_of(t2)
print(f'[键盘上方上滑(220→90)→] {s2} | {t2[:6]}')

t3 = swipe(220, TOP, 'p2_s3'); s3 = screen_of(t3)
print(f'[再键盘上方上滑(220→90)→] {s3} | {t3[:6]}')

t4 = swipe(TOP, 220, 'p2_s4'); s4 = screen_of(t4)
print(f'[下滑(90→220)→] {s4} | {t4[:6]}')

t5 = swipe(TOP, 220, 'p2_s5'); s5 = screen_of(t5)
print(f'[再下滑(90→220)→] {s5} | {t5[:6]}')

print(f'\n覆盖屏序列: {[s0,s1,s2,s3,s4,s5]}')
