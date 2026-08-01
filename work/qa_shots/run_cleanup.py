# QA 收尾：批量清理倒数日测试脏数据（T20V* / QA回归测试 / QA 123 / A关提醒）
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'
MARKS = ('T20V', 'QA回归测试', 'QA 123', 'A关提醒', 'QA测试')


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
        typ = a.get('type', '')
        if t or typ == 'Button':
            res.append((typ, t, a.get('bounds', '')))
        for c in n.get('children', []):
            walk(c)
    walk(d)
    return res


def find(items, kw):
    for t, tx, b in items:
        if kw in tx:
            return parse_b(b)
    return None


def click(x, y):
    sh('shell', 'uitest', 'uiInput', 'click', str(x), str(y))


def click_box(box):
    click((box[0] + box[2]) // 2, (box[1] + box[3]) // 2)


def goto_countdown(tag):
    sh('shell', 'aa', 'force-stop', PKG)
    time.sleep(1)
    sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
    time.sleep(6)
    items = dump(tag + '_home')
    for t, tx, b in items:
        p = parse_b(b)
        if '倒数日' in tx and p and p[1] > 2400:
            click_box(p)
            break
    time.sleep(3)
    return dump(tag)


def is_test(tx):
    return any(m in tx for m in MARKS)


print('=' * 56)
print('QA 收尾 · 清理倒数日测试脏数据')
print('=' * 56)

items = goto_countdown('cl_0')
before = sorted({tx for t, tx, b in items if is_test(tx)})
print(f'[基线] 可见测试条目: {before}')

deleted = 0
for rnd in range(14):
    items = dump(f'cl_r{rnd}')
    tgt, name = None, None
    for t, tx, b in items:
        p = parse_b(b)
        if p and is_test(tx) and 300 < p[1] < 2300:
            tgt, name = p, tx
            break
    if tgt is None:
        # 列表可能需要滚动才能看到剩余项
        sh('shell', 'uitest', 'uiInput', 'swipe', '600', '2000', '600', '1000', '600')
        time.sleep(2)
        items = dump(f'cl_r{rnd}b')
        for t, tx, b in items:
            p = parse_b(b)
            if p and is_test(tx) and 300 < p[1] < 2300:
                tgt, name = p, tx
                break
    if tgt is None:
        print(f'[{rnd}] 已无测试条目，结束')
        break

    click_box(tgt)
    time.sleep(2.5)
    items = dump(f'cl_d{rnd}')
    db = find(items, '删除这个日子')
    if not db:
        print(f'[{rnd}] {name}: ⚠️ 详情页无删除入口，跳过')
        sh('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
        time.sleep(2)
        continue
    click_box(db)
    time.sleep(2.5)

    items = dump(f'cl_g{rnd}')
    conf = None
    for t, tx, b in items:
        p = parse_b(b)
        if p and tx.strip() == '删除' and 800 < (p[1] + p[3]) / 2 < 2000:
            conf = p
            break
    if conf:
        click_box(conf)
        deleted += 1
        print(f'[{rnd}] 删除 {name} ✅')
    else:
        print(f'[{rnd}] {name}: ⚠️ 未定位弹窗删除按钮')
        sh('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
    time.sleep(3)

# 最终核对
items = goto_countdown('cl_final')
left = sorted({tx for t, tx, b in items if is_test(tx)})
alltxt = [x[1] for x in items if x[1]]
print()
print(f'  删除次数: {deleted}')
print(f'  残留测试条目(可视区): {left if left else "无 ✅"}')
print(f'  当前列表: {" | ".join(alltxt)[:260]}')
