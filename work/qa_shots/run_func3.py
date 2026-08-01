"""续跑（安全版，不用 back 键，避免退出应用）：
首页宠物联动 / 设置页 C2 零联网徽章 / 隐私宣言页 / 倒数日无上限(T17)"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def ensure_app():
    """确保伴伴在前台，不在则拉起"""
    o = sh("shell", "aa", "dump", "-l")
    if PKG not in o or "FOREGROUND" not in o:
        sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
        time.sleep(3)
        return False
    return True


def grab(tag, wait=2.0, quiet=False):
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
    # 安全护栏：如果页面不像伴伴（无底部四 Tab 且无伴伴特征词），判定跑偏
    joined = " ".join(x[1] for x in out)
    is_banban = ("首页" in joined and "倒数日" in joined) or "伴伴" in joined \
        or "零联网" in joined or "隐私" in joined or "专注" in joined
    if not quiet:
        print(f"\n===== [{tag}] 控件={c} 伴伴页面={is_banban} =====")
        if not is_banban:
            print("  !! 跑偏，非伴伴页面，跳过内容打印（隐私保护）")
        else:
            for typ, tx, b in out:
                print(f"  [{typ}] {tx}  @{b}")
        print(f"  >>> 存活={not crashed()} 前台={alive()}")
    if not is_banban:
        # 删掉跑偏截图
        for ext in (".jpeg", ".json"):
            p = os.path.join(os.path.dirname(os.path.abspath(__file__)), tag + ext)
            if os.path.exists(p):
                os.remove(p)
        ensure_app()
        return None
    return out


ensure_app()

# 1) 首页看宠物联动（已记 12.50，宠物文案 / 记账卡应变化）
tap(*TABS["home"], wait=2.5)
grab("h1_home_after_bill")

# 2) 设置页（右上角 ⚙ @[1099,611][1238,743] 中心约 1168,677）
tap(1168, 677, wait=2.5)
grab("h2_settings")
