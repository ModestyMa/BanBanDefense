"""BUG 诊断：首页记账卡冷启动仍显示"今天还没记账" —— 抓 hilog 定位是否 load() 抛异常"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, snap, PKG

print("=== 1. 设备时间 ===")
print(sh("shell", "date"))

print("=== 2. 停应用 + 清日志 ===")
sh("shell", "aa", "force-stop", PKG)
time.sleep(1.5)
sh("shell", "hilog", "-r")
time.sleep(0.5)

print("=== 3. 冷启动 ===")
sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
time.sleep(6)

print("=== 4. 抓日志（错误/异常）===")
log = sh("shell", "hilog", "-x", "-L", "E", timeout=60)
keys = ("banban", "BanBan", "RdbStore", "relationalStore", "Error", "error",
        "Exception", "no such", "column", "SQL", "sqlite")
hit = [ln for ln in log.splitlines()
       if any(k in ln for k in keys)]
print(f"总行={len(log.splitlines())} 命中={len(hit)}")
for ln in hit[-90:]:
    print("  " + ln[:300])
