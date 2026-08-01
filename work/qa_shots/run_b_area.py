"""T5 手机端 B 区自动核验 - 主流程遍历"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, show, crashed, alive, back, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}

results = []


def step(name, tag, action=None, wait=2.0):
    if action:
        action()
    time.sleep(wait)
    texts, cnt = snap(tag)
    show(tag, texts, cnt)
    dead = crashed()
    fg = alive()
    print(f"  >>> 存活={not dead} 前台={fg} 控件数={cnt}")
    results.append((name, tag, not dead, fg, cnt, len(texts)))
    if dead:
        print(f"  !!! 崩溃告警: {name}")
    return texts


print("########## B 区主流程自动核验开始 ##########")

# 冷启动
sh("shell", "aa", "force-stop", PKG)
time.sleep(2)
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
step("B1 冷启动首页", "b1_home", wait=4)

# 四 Tab 遍历
step("B2 倒数日Tab", "b2_countdown", lambda: tap(*TABS["countdown"]))
step("B3 番茄Tab", "b3_pomodoro", lambda: tap(*TABS["pomodoro"]))
step("B4 记账Tab", "b4_account", lambda: tap(*TABS["account"]))
step("B5 回首页", "b5_home_back", lambda: tap(*TABS["home"]))

print("\n########## 汇总 ##########")
for r in results:
    flag = "OK " if r[2] and r[3] else "!! "
    print(f"{flag}{r[0]:16s} tag={r[1]:16s} 存活={r[2]} 前台={r[3]} 控件={r[4]} 文本={r[5]}")
