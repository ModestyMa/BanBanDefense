"""T5 功能链路自动核验：记账落库 / 宠物联动 / 设置与隐私宣言(C2)"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG

TABS = {"home": (164, 2670), "countdown": (491, 2670),
        "pomodoro": (818, 2670), "account": (1145, 2670)}


def texts_of(tag, wait=2.0):
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
    return out, c


def p(tag, lst, cnt):
    print(f"\n===== [{tag}] 控件={cnt} =====")
    for typ, tx, b in lst:
        print(f"  [{typ}] {tx}  @{b}")
    print(f"  >>> 存活={not crashed()} 前台={alive()}")


print("########## 功能链路核验 ##########")

# ---- 记一笔 12.5 元餐饮/现金 ----
tap(*TABS["account"], wait=2)
# 金额输入框大致在 ¥ 右侧
tap(900, 445, wait=1.2)
for d in ["1", "2", ".", "5"]:
    sh("shell", "uinput", "-K", "-t", d)
    time.sleep(0.35)
l, c = texts_of("f1_amount_input")
p("F1 输入金额12.5", l, c)

# 选餐饮 + 现金
tap(240, 600, wait=1.0)   # 🍜 餐饮
tap(240, 935, wait=1.0)   # 💵 现金
l, c = texts_of("f2_category_picked")
p("F2 选餐饮+现金", l, c)

# 保存
tap(654, 1255, wait=2.5)
l, c = texts_of("f3_after_save")
p("F3 保存后（应出现流水）", l, c)

# ---- 回首页看宠物联动 ----
tap(*TABS["home"], wait=2.5)
l, c = texts_of("f4_home_after_bill")
p("F4 记账后首页（宠物文案应变化/记账卡应更新）", l, c)

# ---- 设置页 -> 隐私宣言 (C2) ----
tap(1168, 677, wait=2.5)   # 右上 ⚙
l, c = texts_of("f5_settings")
p("F5 设置页（找零联网徽章+隐私承诺入口）", l, c)

print("\n########## 完成 ##########")
