"""P 组 A/B 对照：验证「force-stop 后快速重启」是否为首页数据加载失败的触发条件
A 组：kill 后 2.0s 重启   B 组：kill 后 5.0s 重启   各 6 轮"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, snap, PKG


def round_once(tag, gap):
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(gap)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    t, c = snap(tag)
    txt = [x[1] for x in t]
    joined = " ".join(txt)
    pet = next((s for s in txt if "🔥" in s), "?")
    bill = next((s for s in txt if "支出" in s and "笔" in s), None)
    pet_ok = "今天已打卡" in joined
    return pet, pet_ok, bill


for grp, gap in (("A", 2.0), ("B", 5.0)):
    fail = 0
    print(f"\n########## {grp} 组：kill 后 {gap}s 重启 ##########")
    for i in range(1, 7):
        pet, pet_ok, bill = round_once(f"p{grp}{i}", gap)
        bad = bill is None
        fail += 1 if bad else 0
        flag = "❌失败" if bad else "✅通过"
        print(f"  [{grp}{i}] {flag} 宠物={pet} 已打卡={pet_ok} 记账卡={bill or '今天还没记账'}")
    print(f"  >>> {grp} 组失败 {fail}/6（{fail/6*100:.0f}%）")
