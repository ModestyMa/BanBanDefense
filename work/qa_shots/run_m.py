"""M 组（稳健版）：记账 -> 首页 实时刷新判定（B-6 核心）"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}
CARD = ["记账", "专注", "倒数日", "天", "打卡", "笔", "还没", "支出", "收入"]


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
    joined = " ".join(x[1] for x in out)
    page = "首页" if ("番茄专注" in joined and "倒数日" in joined and "记账" in joined) \
        else ("记账页" if "保存" in joined or "银行卡" in joined else "?")
    print(f"\n===== [{tag}] 控件={c} 页面={page} =====")
    for typ, tx, b in out:
        if keys is None or any(k in tx for k in keys):
            print(f"  [{typ}] {tx}  @{b}")
    print(f"  >>> 存活={not crashed()} 前台={alive()}")
    return out, page


# 0) 冷启动回首页，拿基线
sh("shell", "aa", "force-stop", PKG)
time.sleep(2)
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(7)
grab("m0_home_base", wait=1.5, keys=CARD)

# 1) 切记账页，记一笔 3.50
tap(*TABS["account"], wait=3.0)
tap(900, 445, wait=1.8)
for d in ["3", ".", "5", "0"]:
    sh("shell", "uinput", "-K", "-t", d)
    time.sleep(0.45)
grab("m1_amount", wait=1.2, keys=["3.5", "¥"])
tap(240, 600, wait=1.2)    # 餐饮
tap(240, 935, wait=1.2)    # 现金
tap(654, 1255, wait=3.5)   # 保存
grab("m2_saved", wait=1.5, keys=["3.50", "8.88", "今天", "昨天"])

# 2) 让输入框失焦（点账户区与保存键之间的空白），再切首页
tap(660, 1080, wait=1.5)
tap(*TABS["home"], wait=2.5)
out, page = grab("m3_home_realtime", wait=2.5, keys=CARD)
if page != "首页":
    print("\n[!] Tab 切换被键盘拦截，改用冷启动兜底验证")
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(7)
    grab("m4_home_cold", wait=1.5, keys=CARD)
