"""O 组：循环冷启动直到复现首页加载失败，抓 domain 0x1500 / HomePage 日志锁根因"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, snap, PKG

KEY = ("HomePage", "0x1500", "1500/", "banban/A0", "RdbStore", "relationalStore",
       "preferences", "Preferences", "rdb", "RDB", "database", "Database",
       "not an error", "14800", "sqlite")

for i in range(1, 9):
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2)
    sh("shell", "hilog", "-r")
    time.sleep(0.4)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    t, c = snap(f"o{i}_cold")
    txt = [x[1] for x in t]
    joined = " ".join(txt)
    pet = next((s for s in txt if "🔥" in s), "?")
    bill = next((s for s in txt if "支出" in s and "笔" in s), None)
    good = bill is not None
    print(f"[第{i}轮] 宠物={pet} | 记账卡={'✅' if good else '❌ 空'}")
    if not good:
        print("  --- 复现失败轮，抓日志 ---")
        log = sh("shell", "hilog", "-x", timeout=90)
        hit = [ln for ln in log.splitlines()
               if PKG in ln and any(k in ln for k in KEY)]
        print(f"  本轮伴伴相关命中 {len(hit)} 行：")
        for ln in hit[:60]:
            print("    " + ln[:280])
        break
