"""Q 组：不清日志循环冷启动，命中失败轮后抓 HomePage / 0x1500 域日志（拿 load() 抛出的原文）"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autotest import sh, snap, PKG

for i in range(1, 11):
    sh("shell", "aa", "force-stop", PKG)
    time.sleep(2.5)
    sh("shell", "aa", "start", "-a", "EntryAbility", "-b", PKG)
    time.sleep(8)
    t, c = snap(f"q{i}_cold")
    txt = [x[1] for x in t]
    bill = next((s for s in txt if "支出" in s and "笔" in s), None)
    print(f"[第{i}轮] {'✅' if bill else '❌ 失败'}")
    if bill:
        continue

    print("  === 命中失败轮，抓日志 ===")
    log = sh("shell", "hilog", "-x", timeout=90)
    lines = log.splitlines()
    hits = [ln for ln in lines
            if ("HomePage" in ln) or ("DatabaseHelper" in ln)
            or ("0x1500" in ln) or ("1500/" in ln)
            or (PKG in ln and ("未初始化" in ln or "加载失败" in ln))]
    print(f"  HomePage/DB 相关命中 {len(hits)} 行")
    for ln in hits[-40:]:
        print("    " + ln[:300])

    # 补充：应用自身所有 W/E 级
    we = [ln for ln in lines if PKG in ln and (" W " in ln or " E " in ln)
          and "WMS" not in ln and "Ace" not in ln]
    print(f"\n  应用 W/E 级（去 WMS/Ace 噪音）{len(we)} 行，尾 25：")
    for ln in we[-25:]:
        print("    " + ln[:300])
    break
