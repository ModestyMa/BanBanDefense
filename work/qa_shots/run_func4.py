"""C2 隐私宣言页核验 + 首页记账卡刷新 Bug 复现"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, tap, snap, crashed, alive, PKG
from run_func3 import grab, ensure_app, TABS

ensure_app()

# 当前在设置页 -> 点「隐私承诺」(C2 隐私宣言页)
tap(654, 408, wait=2.5)
grab("i1_privacy_manifest")

# 返回设置（页面内左上返回，若无则用 aa start 回首页）
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(3)

# 复现记账卡刷新问题：重新进首页看是否已更新
tap(*TABS["home"], wait=2.5)
grab("i2_home_recheck")
