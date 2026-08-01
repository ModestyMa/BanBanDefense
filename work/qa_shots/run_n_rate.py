"""N 组：冷启动首页三卡加载 间歇性失败 复现率统计（每轮冷启动，记录宠物行 + 三卡文案）"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, snap, PKG

N = 6
ok = 0
for i in range(1, N + 1):
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    t, c = snap(f"n{i}_cold")
    txt = [x[1] for x in t]
    joined = " ".join(txt)
    pet = next((s for s in txt if "🔥" in s), "?")
    checked = "今天已打卡" in joined
    bill = next((s for s in txt if "支出" in s and "笔" in s), None)
    empty = "今天还没记账" in joined
    good = bill is not None and not empty
    ok += 1 if good else 0
    print(f"[第{i}轮] 宠物={pet} 已打卡={checked} | 记账卡={'✅ ' + bill if bill else '❌ 今天还没记账'}")

print(f"\n>>> 冷启动 {N} 次，记账卡正确 {ok} 次，失败 {N-ok} 次，失败率 {(N-ok)/N*100:.0f}%")
