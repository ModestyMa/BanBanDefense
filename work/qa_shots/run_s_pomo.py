"""S 组：番茄钟倒计时是否正常跳动（验证 mmss() 等私有方法的依赖收集是否同样失效）"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def clock(tag):
    t, c = snap(tag)
    txt = [x[1] for x in t]
    tm = next((s for s in txt if ":" in s and len(s) <= 6 and s.replace(":", "").isdigit()), None)
    hint = [s for s in txt if s in ("准备专注？",) or "专注" in s and len(s) < 10]
    return tm, hint, txt


sh("shell", "aa", "force-stop", PKG)
time.sleep(2.5)
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(8)

tap(*TABS["pomodoro"], wait=3.0)
tm0, h0, _ = clock("s0_pomo_idle")
print(f"[s0 初始] 计时={tm0} 提示={h0}")

# 点「开始专注」
tap(654, 2404, wait=3.0)
tm1, h1, txt1 = clock("s1_started")
print(f"[s1 开始后3s] 计时={tm1} 提示={h1}")

time.sleep(8)
tm2, h2, _ = clock("s2_after_8s")
print(f"[s2 再等8s] 计时={tm2}")

time.sleep(8)
tm3, h3, _ = clock("s3_after_16s")
print(f"[s3 再等8s] 计时={tm3}")

print(f"\n>>> 判定：{'✅ 倒计时正常跳动' if (tm1 != tm2 or tm2 != tm3) else '❌ 倒计时不跳动（依赖收集失效）'}")
print(f"    序列: {tm0} -> {tm1} -> {tm2} -> {tm3}")

# 收尾：不留运行中的番茄，回首页
tap(*TABS["home"], wait=2.0)
