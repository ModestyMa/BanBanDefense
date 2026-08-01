"""L 组：①记账→首页 实时刷新判定 ②倒数日 T17 无上限验证"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}
CARD = ["记账", "专注", "倒数日", "天", "打卡", "笔", "还没", "支出", "收入"]


def grab(tag, wait=2.0, keys=None, quiet=False):
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


print("设备时间:", sh("shell", "date").strip())

# ---------- L1 记账 -> 首页 实时刷新 ----------
tap(*TABS["account"], wait=2.0)
tap(900, 445, wait=1.0)
for d in ["3", ".", "5", "0"]:
    sh("shell", "uinput", "-K", "-t", d)
    time.sleep(0.3)
tap(240, 600, wait=0.8)    # 餐饮
tap(240, 935, wait=0.8)    # 现金
tap(654, 1255, wait=3.0)   # 保存
grab("l1_saved", keys=["3.50", "8.88", "今天", "昨天"])

# 收键盘：点页面空白区（标题栏下方无控件处）
tap(660, 1400, wait=1.0)
# 切首页（点两次保证生效）
tap(*TABS["home"], wait=2.0)
tap(*TABS["home"], wait=3.5)
grab("l2_home_realtime", keys=CARD)

# ---------- L2 倒数日 T17 无上限 ----------
tap(*TABS["countdown"], wait=2.5)
grab("l3_countdown_list", keys=["倒数日", "还没有", "+", "天"])
