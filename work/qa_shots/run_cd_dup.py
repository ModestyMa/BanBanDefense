# 验证：保存失败提示下数据是否已入库 + 重试是否产生重复
import time, subprocess, json, re, os, sys

HDC = r'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
SN = sys.argv[sys.argv.index('-t') + 1] if '-t' in sys.argv else '192.168.43.6:33359'
PKG = 'com.modestyma.banban'
OUT = 'work/qa_shots'


def sh(*a, timeout=90):
    r = subprocess.run([HDC, '-t', SN] + list(a), capture_output=True,
                       text=True, encoding='utf-8', errors='ignore', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


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
        typ = a.get('type', '')
        if t or typ in ('TextInput', 'TextArea', 'Button'):
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


def click_box(box):
    sh('shell', 'uitest', 'uiInput', 'click', str((box[0] + box[2]) // 2), str((box[1] + box[3]) // 2))


print('=== 验证「保存失败」是否真失败 ===\n')

# 当前应仍停在表单页（上一脚本结束态）。再点一次保存，模拟用户重试
items = dump('dup0_now')
cur = ' | '.join(x[1] for x in items if x[1])
print(f'[0] 当前页: {cur[:120]}')

on_form = '新建倒数日' in cur or '编辑倒数日' in cur
if on_form:
    save = find(items, '保存')
    if save:
        print('[1] 模拟用户重试：再点一次保存')
        click_box(save)
        time.sleep(3)
    # 再点一次（第三次）
    items = dump('dup1_retry')
    save = find(items, '保存')
    if save:
        print('[2] 第三次点保存')
        click_box(save)
        time.sleep(3)
    # 返回列表
    items = dump('dup2_form')
    back = find(items, '返回')
    if back:
        print('[3] 点返回退出表单')
        click_box(back)
        time.sleep(2.5)
else:
    print('[1] 不在表单页，跳过重试')

# 冷启动后看列表真实数据
print('\n[4] 冷启动重进倒数日，统计条目')
sh('shell', 'aa', 'force-stop', PKG)
time.sleep(1)
sh('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', PKG)
time.sleep(6)
items = dump('dup3_home')
tab = None
for t, tx, b in items:
    p = parse_b(b)
    if '倒数日' in tx and p and p[1] > 2400:
        tab = p
        break
if tab:
    click_box(tab)
time.sleep(3)

items = dump('dup4_list')
texts = [x[1] for x in items if x[1]]
n = sum(1 for t in texts if 'QA回归测试' in t)
print(f'\n[5] 列表中「QA回归测试」条目数 = {n}')
print(f'[6] 列表全文: {" | ".join(texts)[:300]}')
print()
if n == 0:
    print('  判定：数据未入库 → 报错=真失败')
elif n == 1:
    print('  判定：🐞 数据已入库但提示保存失败（假失败），重试未重复')
else:
    print(f'  判定：🐞🐞 数据污染！点了 3 次保存产生 {n} 条重复记录')
