"""R 组：失败态下切 Tab 再切回，判定是「UI 未重绘」还是「数据真没加载」
- 切回后数据出现 => 数据已在 VM，纯 UI 刷新时机问题
- 切回后仍为空 => @Trace 依赖收集失效 / 数据确实没加载"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def home_state(tag):
    t, c = snap(tag)
    txt = [x[1] for x in t]
    joined = " ".join(txt)
    pet = next((s for s in txt if "🔥" in s), "?")
    bill = next((s for s in txt if "支出" in s and "笔" in s), None)
    is_home = "番茄专注" in joined
    return pet, bill, is_home


for i in range(1, 11):
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2.5)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    pet, bill, is_home = home_state(f"r{i}_cold")
    print(f"[第{i}轮] 冷启动: 宠物={pet} 记账卡={bill or '❌空'}")
    if bill:
        continue

    print("  >>> 命中失败态，执行 切倒数日 -> 切回首页")
    tap(*TABS["countdown"], wait=2.5)
    tap(*TABS["home"], wait=3.0)
    pet2, bill2, is_home2 = home_state(f"r{i}_after_tabswitch")
    print(f"      切回后: 在首页={is_home2} 宠物={pet2} 记账卡={bill2 or '❌仍空'}")

    print("  >>> 再等 6 秒复查（排除单纯慢）")
    time.sleep(6)
    pet3, bill3, _ = home_state(f"r{i}_after_wait")
    print(f"      等待后: 宠物={pet3} 记账卡={bill3 or '❌仍空'}")
    break
