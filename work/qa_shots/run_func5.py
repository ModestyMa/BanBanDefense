"""复现首页记账卡刷新问题 + 验 C2 隐私承诺页(零联网徽章)"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG
from run_func3 import grab, ensure_app, TABS

# 冷重启回首页（隐私政策页可能压栈）
sh("shell", "aa", "force-stop", PKG)
time.sleep(2)
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(4)

# 场景1：冷启动后首页 —— 记账卡是否已反映 12.50
grab("j1_cold_home")

# 场景2：切到记账 Tab 再切回首页 —— 是否刷新
tap(*TABS["account"], wait=2.5)
tap(*TABS["home"], wait=2.5)
grab("j2_home_after_switch")

# 场景3：进设置 -> 隐私承诺（C2 宣言页，第一项 🛡 @[112,367] 行）
tap(1168, 670, wait=2.5)   # ⚙
grab("j3_settings", quiet=True)
tap(654, 408, wait=3.0)    # 隐私承诺行
r = grab("j4_privacy_manifest")
