"""续跑：首页宠物联动 / 设置页 C2 零联网徽章 / 隐私宣言页 / 倒数日无上限(T17)"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def kb_off():
    sh("shell", "uinput", "-K", "-d", "2", "-u", "2")
    time.sleep(1.2)


def grab(tag, wait=2.0):
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
        print(f"  [{typ}] {tx}  @{b}")
    print(f"  >>> 存活={not crashed()} 前台={alive()}")
    return out


kb_off()

# 1) 首页看宠物联动（已记账，文案应从"今天还没记账"变化）
tap(*TABS["home"], wait=2.5)
grab("g1_home_after_bill")

# 2) 设置页
tap(1168, 677, wait=2.5)
grab("g2_settings")
