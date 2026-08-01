"""离线解析已有 dump（不连设备），批量提取每个场景的可见文本"""
import json, os, sys, glob

OUT = os.path.dirname(os.path.abspath(__file__))


def texts_of(path):
    try:
        d = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        return [("<ERR>", str(e), "")]
    res = []

    def walk(n):
        a = n.get("attributes", {})
        t = (a.get("text") or "").strip()
        if t:
            res.append((a.get("type", ""), t, a.get("bounds", "")))
        for c in n.get("children", []):
            walk(c)

    walk(d)
    return res


order = ["b1_home", "b2_countdown", "b3_pomodoro", "b4_account", "b5_home_back",
         "f1_amount_input", "f2_category_picked", "f3_after_save",
         "h1_home_after_bill", "h2_settings",
         "i1_privacy_manifest", "i2_home_recheck",
         "j1_cold_home", "j2_home_after_switch", "j3_settings", "j4_privacy_manifest"]

only = sys.argv[1:] if len(sys.argv) > 1 else order
for tag in only:
    p = os.path.join(OUT, tag + ".json")
    if not os.path.exists(p):
        print(f"\n##### [{tag}] 缺失")
        continue
    ts = texts_of(p)
    body = []
    for typ, t, b in ts:
        try:
            y = int(b.split("][")[0].split(",")[1])
        except Exception:
            y = 999
        if y >= 200:
            body.append(f"[{typ}] {t} @{b}")
    print(f"\n##### [{tag}] 文本节点={len(body)}")
    for line in body:
        print("   " + line)
