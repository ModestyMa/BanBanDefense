# Bug 清单（QA 维护，唯一登记处）

- 规则：QA 只登记与指派，不改码；主程序修完标「待复验」，QA 复验通过标「关闭」
- 严重级：P0 崩溃/数据丢失 ｜ P1 功能错误 ｜ P2 视觉/规范违规 ｜ P3 建议/观察

| 编号 | 端 | 复现步骤/位置 | 预期 | 实际 | 严重级 | 状态 | 指派给 |
|---|---|---|---|---|---|---|---|
| BUG-001 | entry | 实况：`pages/pomodoro/PomodoroTimerPage.ets:342` `@CustomDialog struct CustomTagDialog` 内 V1 `@State inputText`（**未改 @Local**，交接单描述不实） | 06 §2-8：新代码统一 V2、同组件不混 V1/V2 | **QA 复验裁定（2026-08-01）**：①技术主张成立——@CustomDialog 属 V1 组件体系、与 @ComponentV2 互斥，其内不可用 @Local，V1 @State 合法（代码注释 336-337 属实）；②但定性纠正——CustomTagDialog 是**纯 V1 存量代码**（番茄钟 W2/W3 期，整 struct 无 V2 装饰器）→**不构成"同组件混用"、非新代码，不违反 §2-8**；③彻底 V2 化的正解是迁 `promptAction.openCustomDialog()`+@ComponentV2 builder（约 15-20 分钟+需回归自定义标签弹窗，冻结期不推荐） | 建议 P2→**P3** | **QA 裁定完成·待 PM 拍板**（建议改判 P3 存量豁免、不强制改，随 OBS-001 口径一并定；主程序**不得自闭环**；T15 已于 2026-08-01 据本裁定更正 T7 交接单不实描述，本行状态保持「QA 裁定完成·待 PM 拍板」） | PM 拍板（T15 交接单更正已完成） |
| BUG-002 | entry+wearable | `pages/home/HomePage.ets:96`、`wearable .../WatchOverviewPage.ets:31` | 06 §2-5：字符串一律 `$r('app.string.xxx')` | 已改为 `$r('app.string.home_streak_fmt', N)`；**QA 代码侧复验通过（2026-08-01）**：双端 HomePage:96 / WatchOverviewPage:31 均已用 `$r`，`home_streak_fmt`="🔥 %d 天" 在 entry string.json:121 + wearable string.json:39 双端齐备 | P2 | 已修·**QA 代码侧复验通过**，运行期随 T5/T8 顺带确认后关闭 | 主程序（待 T5/T8 运行确认关闭） |
| BUG-003 | 全端 | 静态走查：硬编码颜色约 40 处。高风险子集：①`widget/pages/PetCard.ets:21-22` `'#F0764F'/'#F2FFFFFF'`（卡片深色模式）②`AccountManagePage.ets:187`/`AccountPage.ets:377` 遮罩 `'#66000000'` ③`AccountReportPage.ets:112` Canvas `'#F0EBE4'`（深色下环形图底色）；低风险：shadow 色值、`Color.White/Transparent` | 06 §2-5：颜色一律 `$r('app.color.xxx')` | 深色模式下卡片/遮罩/Canvas 可能出现对比度事故；具体表现待 T10 深浅色核验确认 | P2（若 F 区核验出视觉事故升 P1） | **已修待复验**（2026-08-01 主程序：高风险 5 处 + PetCard 其余 3 处全部 → `$r`；`ring_track` Canvas 运行时解析；同步补全 entry/wearable 深色调色板（34/12 色）；shadow 与 palette 兜底按低风险保留。详见 reports/2026-08-01_主程序_P0批量清障.md。**复验请并入 T10 深浅色核验**） | 主程序（待 T10 复验关闭） |

## 观察项（不计 Bug，供决策）

| 编号 | 说明 | 建议 |
|---|---|---|
| OBS-001 | fontSize/间距等数字尺寸普遍未走 `$r('app.float.xxx')`，严格按 06 §2-5 属违规，但全仓量大、W5 已定型 | 建议老板定口径：MVP 豁免存量、新代码（C1-C3 特色）强制 `$r()`；避免冻结期大改引入回归 |
| OBS-002 | repository 层用 try/finally 关资源、异常上抛，catch 兜底在 viewmodel/pages/service 层（已抽查覆盖广泛）；个别 VM（HomeViewModel/PomodoroViewModel）自身无 catch，依赖页面层兜底 | 架构成立，不改；T5/T8 回归时重点观察 DB 异常场景是否有 toast 而非崩溃 |
| OBS-003 | 走查通过项：any/unknown 零命中 ✅ 解构零命中 ✅ 页面直连 DB 零命中（entry+wearable 全部走 repository）✅ exp 联动仅在两个 PetEngine.ets ✅ V1 装饰器全仓仅 BUG-001 一处 ✅ toast 文案全部 `$r()` ✅ | — |
