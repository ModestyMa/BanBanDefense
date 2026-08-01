"""K 组：首页记账卡「今天还没记账」干净复现（当日新记一笔后立即回首页 + 冷启动二次确认）"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def grab(tag, wait=2.0, keys=None):
    time.sleep(wait)
    t, c = snap(tag)
    out = []
    for typ, tx, b in t:
        try:
            y = int(b.split("][")[0].split(",")[1])
        except Exception:
            y = 999
        if y >= 200:
            out.append((typ, tx, b))
    print(f"\n===== [{tag}] 控件={c} =====")
    for typ, tx, b in out:
        if keys is None or any(k in tx for k in keys):
            print(f"  [{typ}] {tx}  @{b}")
    print(f"  >>> 存活={not crashed()} 前台={alive()}")
    return out


CARD = ["记账", "专注", "倒数日", "天", "打卡", "¥", "笔", "还没"]

print("设备时间:", sh("shell", "date").strip())

# 0) 当前首页（跨日后基线）
tap(*TABS["home"], wait=2.0)
grab("k0_home_baseline", keys=CARD)

# 1) 记一笔 8.88 餐饮/现金
tap(*TABS["account"], wait=2.0)
tap(900, 445, wait=1.2)
for d in ["8", ".", "8", "8"]:
    sh("shell", "uinput", "-K", "-t", d)
    time.sleep(0.35)
tap(240, 600, wait=1.0)   # 餐饮
tap(240, 935, wait=1.0)   # 现金
tap(654, 1255, wait=3.0)  # 保存
grab("k1_after_save", keys=["8.88", "餐饮", "现金", "今天", "还没"])

# 2) 立刻回首页 —— 核心判定点
tap(*TABS["home"], wait=3.0)
grab("k2_home_after_bill", keys=CARD)

# 3) 冷启动二次确认
sh("shell", "aa", "force-stop", PKG)
time.sleep(2)
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(6)
grab("k3_home_cold", keys=CARD)
