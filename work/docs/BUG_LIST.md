# Bug 清单（QA 维护，唯一登记处）

- 规则：QA 只登记与指派，不改码；主程序修完标「待复验」，QA 复验通过标「关闭」
- 严重级：P0 崩溃/数据丢失 ｜ P1 功能错误 ｜ P2 视觉/规范违规 ｜ P3 建议/观察

| 编号 | 端 | 复现步骤/位置 | 预期 | 实际 | 严重级 | 状态 | 指派给 |
|---|---|---|---|---|---|---|---|
| BUG-001 | entry | 静态走查：`pages/pomodoro/PomodoroTimerPage.ets:340` `@CustomDialog struct CustomTagDialog` 内使用 V1 `@State inputText` | 06 §2-8：新代码统一 V2（@Local） | V1 装饰器出现在 V2 工程中；@ComponentV2 页面弹 V1 CustomDialog 属已知兼容风险，自定义标签输入可能不响应 | P2 | 待修 | 主程序 |
| BUG-002 | entry+wearable | 静态走查：`pages/home/HomePage.ets:96`、`wearable .../WatchOverviewPage.ets:31` `Text('🔥 ' + ... + ' 天')` | 06 §2-5：字符串一律 `$r('app.string.xxx')` | 中文「天」硬编码在代码中（全仓仅此 2 处） | P2 | 待修 | 主程序 |
| BUG-003 | 全端 | 静态走查：硬编码颜色约 40 处。高风险子集：①`widget/pages/PetCard.ets:21-22` `'#F0764F'/'#F2FFFFFF'`（卡片深色模式）②`AccountManagePage.ets:187`/`AccountPage.ets:377` 遮罩 `'#66000000'` ③`AccountReportPage.ets:112` Canvas `'#F0EBE4'`（深色下环形图底色）；低风险：shadow 色值、`Color.White/Transparent` | 06 §2-5：颜色一律 `$r('app.color.xxx')` | 深色模式下卡片/遮罩/Canvas 可能出现对比度事故；具体表现待 T10 深浅色核验确认 | P2（若 F 区核验出视觉事故升 P1） | 待修（可与 T10 结果合并处理） | 主程序 |

## 观察项（不计 Bug，供决策）

| 编号 | 说明 | 建议 |
|---|---|---|
| OBS-001 | fontSize/间距等数字尺寸普遍未走 `$r('app.float.xxx')`，严格按 06 §2-5 属违规，但全仓量大、W5 已定型 | 建议老板定口径：MVP 豁免存量、新代码（C1-C3 特色）强制 `$r()`；避免冻结期大改引入回归 |
| OBS-002 | repository 层用 try/finally 关资源、异常上抛，catch 兜底在 viewmodel/pages/service 层（已抽查覆盖广泛）；个别 VM（HomeViewModel/PomodoroViewModel）自身无 catch，依赖页面层兜底 | 架构成立，不改；T5/T8 回归时重点观察 DB 异常场景是否有 toast 而非崩溃 |
| OBS-003 | 走查通过项：any/unknown 零命中 ✅ 解构零命中 ✅ 页面直连 DB 零命中（entry+wearable 全部走 repository）✅ exp 联动仅在两个 PetEngine.ets ✅ V1 装饰器全仓仅 BUG-001 一处 ✅ toast 文案全部 `$r()` ✅ | — |
