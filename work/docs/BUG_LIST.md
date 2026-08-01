# Bug 清单（QA 维护，唯一登记处）

- 规则：QA 只登记与指派，不改码；主程序修完标「待复验」，QA 复验通过标「关闭」
- 严重级：P0 崩溃/数据丢失 ｜ P1 功能错误 ｜ P2 视觉/规范违规 ｜ P3 建议/观察

| 编号 | 端 | 复现步骤/位置 | 预期 | 实际 | 严重级 | 状态 | 指派给 |
|---|---|---|---|---|---|---|---|
| BUG-001 | entry | 实况：`pages/pomodoro/PomodoroTimerPage.ets:342` `@CustomDialog struct CustomTagDialog` 内 V1 `@State inputText`（**未改 @Local**，交接单描述不实） | 06 §2-8：新代码统一 V2、同组件不混 V1/V2 | **QA 复验裁定（2026-08-01）**：①技术主张成立——@CustomDialog 属 V1 组件体系、与 @ComponentV2 互斥，其内不可用 @Local，V1 @State 合法（代码注释 336-337 属实）；②但定性纠正——CustomTagDialog 是**纯 V1 存量代码**（番茄钟 W2/W3 期，整 struct 无 V2 装饰器）→**不构成"同组件混用"、非新代码，不违反 §2-8**；③彻底 V2 化的正解是迁 `promptAction.openCustomDialog()`+@ComponentV2 builder（约 15-20 分钟+需回归自定义标签弹窗，冻结期不推荐） | 建议 P2→**P3** | **QA 裁定完成·待 PM 拍板**（建议改判 P3 存量豁免、不强制改，随 OBS-001 口径一并定；主程序**不得自闭环**；T15 已于 2026-08-01 据本裁定更正 T7 交接单不实描述，本行状态保持「QA 裁定完成·待 PM 拍板」） | PM 拍板（T15 交接单更正已完成） |
| BUG-002 | entry+wearable | `pages/home/HomePage.ets:96`、`wearable .../WatchOverviewPage.ets:31` | 06 §2-5：字符串一律 `$r('app.string.xxx')` | 已改为 `$r('app.string.home_streak_fmt', N)`；**QA 代码侧复验通过（2026-08-01）**：双端 HomePage:96 / WatchOverviewPage:31 均已用 `$r`，`home_streak_fmt`="🔥 %d 天" 在 entry string.json:121 + wearable string.json:39 双端齐备 | P2 | 已修·QA 代码侧复验通过；**2026-08-02 entry 侧真机运行确认通过**（首页实测渲染「🔥 2 天」，跨日后正确递增到 2 天，`home_streak_fmt` 资源格式化生效）；wearable 侧待 T9 后整体关闭 | 主程序（仅剩 wearable 侧待 T9 确认） |
| BUG-003 | 全端 | 静态走查：硬编码颜色约 40 处。高风险子集：①`widget/pages/PetCard.ets:21-22` `'#F0764F'/'#F2FFFFFF'`（卡片深色模式）②`AccountManagePage.ets:187`/`AccountPage.ets:377` 遮罩 `'#66000000'` ③`AccountReportPage.ets:112` Canvas `'#F0EBE4'`（深色下环形图底色）；低风险：shadow 色值、`Color.White/Transparent` | 06 §2-5：颜色一律 `$r('app.color.xxx')` | 深色模式下卡片/遮罩/Canvas 可能出现对比度事故；具体表现待 T10 深浅色核验确认 | P2（若 F 区核验出视觉事故升 P1） | **已修待复验**（2026-08-01 主程序：高风险 5 处 + PetCard 其余 3 处全部 → `$r`；`ring_track` Canvas 运行时解析；同步补全 entry/wearable 深色调色板（34/12 色）；shadow 与 palette 兜底按低风险保留。详见 reports/2026-08-01_主程序_P0批量清障.md。**复验请并入 T10 深浅色核验**） | 主程序（待 T10 复验关闭） |

| BUG-004 | entry（手机实测，四端同源） | **冷启动首页三卡（倒数日/番茄/记账）随机停留空状态**。复现：真机 `7ST0226414020964` 冷启动 App → 看首页记账卡。**实测 32 次冷启动，9 次失败，复现率 28%**（N组 3/6、A组 2/6、B组 2/6、R组 1/5、Q组 1/1；kill 间隔 2s vs 5s 失败率同为 33%，与重启快慢无关）。**失败后不可自愈**：切倒数日 Tab 再切回首页仍空、再等 6 秒仍空，必须杀进程重启。典型失败态自相矛盾——宠物卡已是「🔥 2 天／今天已打卡 ✓」（真实数据），同一屏记账卡却显示「今天还没记账」（实际当日已有 3 笔 -15.88） | 首页三卡显示当日真实数据 | 三卡永久停留 @Trace 初值；用户感知为「今天记的账不见了」 | **P1（建议按 P0 优先级插队，不修不建议上架）** | **✅ 已关闭（2026-08-02 QA 双端复验：手机 20/20 + 平板 20/20 冷启动零失败）** | 主程序 |
| BUG-005 | wearable（手表 RTS-AL00 真机） | 手表主页面 `WatchMainPage.ets:10-21` 使用 `Swiper().vertical(true)` 实现三屏竖滑导航（概览/快记/倒数日），但 Swiper **不响应任何滑动输入**。QA 用以下全部方式尝试均无法切换页面：
① uinput `-m` swipe（5 种策略：长距慢速/短距快速/偏左/偏右/中心大滑）
② uitest `uiInput swipe 233 380 233 80 600`
③ uitest `uiInput dircFling 1 6000`（方向 up）
每次滑动后 dumpLayout 文本完全一致（概览屏 7 个 Text 节点不变），截图也确认页面未切换。
**根因（QA 已定位）**：三屏子组件全部设置 `height('100%')` 填满 Swiper，且内部含可滚动容器——`WatchOverviewPage.ets:20` 有 `Scroll().height('100%)'`、`WatchQuickAddPage.ets:169` 外层 `.height('100%')` + 内部 `Scroll()`、`WatchCountdownPage.ets:85` 外层 `.height('100%')` + 内部 `List()`。**竖滑手势被子组件的 Scroll/List 拦截，Swiper 收不到触摸事件**（ArkUI 经典手势冲突）。 | 上滑切换到快记屏、再上滑切换到倒数日屏 | 始终停在概览屏，三屏竖滑完全不可用 | **P1（功能错误：核心导航方式失效；圣人拍板保留手表端，必修）** | **已修复·待复验（主程序 2026-08-02 提交，待 QA 复验）** | 主程序 |

| BUG-006 | entry（手机 SCA-AL00 实测，四端同源） | **倒数日新增/编辑保存报错「The number of reminders exceeds the limit」+ 数据污染**。复现步骤：① 冷启动 App → 进倒数日 Tab → 点「+」新建 → 输入标题 → 点保存 → **提示「保存失败」但数据已入库** → 用户重试 → **产生重复记录**（QA 实测点 3 次保存产生 3 条完全相同的重复条目）。编辑已有事件同样报错（不改内容直接点保存即复现）。关闭「到期提醒」Toggle 后保存成功（0 条失败日志）→ **根因 100% 锁定在提醒调度链路**。
**根因链路**：系统通知权限未开启（全仓搜不到任何 `requestEnableNotification` 调用）→ Ans 服务将提醒配额判为 0 → `ReminderService.publishOne().publishReminder()` 抛错 "The number of reminders exceeds the limit[0]" → `saveEvent()` 内 `refreshReminders()` reject → 整个 Promise 链 reject → `onSave()` catch 触发 toast「保存失败」。但 `insert()/update()` 在 `refreshReminders()` **之前已执行完毕** → 数据已入库却提示失败 → 用户重试导致重复插入。
hilog 关键日志：
```
Ans: ReminderControl com.modestyma.banban, notification not allowed.
ANS_REMINDER: The number of reminders exceeds the limit[0].
CountdownEditPage: 保存失败: The number of reminders exceeds the limit.
```
**番茄钟同服务不同命**：`PomodoroEngine.ets:136-142` 对 `scheduleAt` 用 `.catch()` 静默降级（✅ 正确）；`CountdownViewModel.ets:38-54` 的 `saveEvent` 让 `refreshReminders` 未 catch 直接上抛（❌ 错误）。 | 新增/编辑后提示保存成功并返回列表页，无重复数据 | 提示「保存失败」但数据已入库；重试产生重复记录；默认设置下新增/编辑 **100% 必失败**（remindEnabled 默认 true + 日期默认今天 = 必走 publishReminder） | **P0（数据污染：重复插入 + 假失败误导用户）** | **已修复·待复验（主程序 2026-08-02 提交，待 QA 复验）** | 主程序 |

> **BUG-006 根因与修法（QA 已定位到行，仅供主程序参考，QA 不改码）**
> 1. **根因**：`CountdownViewModel.saveEvent()` (L38-54) 中 `refreshReminders()` (L44/L49) 未被 try/catch 包裹，其内部的 `ReminderService.scheduleForEvent()` (L58) → `publishOne()` (L40) → `reminderAgentManager.publishReminder(req)` (L59) 因通知权限未开启抛错 → 错误沿调用栈冒泡到 `onSave()` (L85) → 显示「保存失败」toast。而 `insert()` (L42) / `update()` (L48) 在此之前已完成 → 数据已入库。
> 2. **扩散面**：`EntryAbility.onCreate:23` 调用 `ReminderService.reconcile()` (L132) 被 try/catch 包裹 ✅ 不影响启动；`PomodoroEngine.scheduleEndReminder()` (L136) 有 `.catch()` 静默降级 ✅ 不影响番茄钟。仅 `CountdownViewModel.saveEvent()` 一处受影响。
> 3. **建议修法（两步都要做）**：
>    - **Step A（必须）**：`CountdownViewModel.saveEvent()` 中把 `refreshReminders()` 用 try/catch 包裹，失败时仅 hilog.warn 不阻断保存流程（参照 PomodoroEngine 同款写法）。这样即使通知权限未开启，倒数日增改也能正常保存。
>    - **Step B（建议）**：在 App 启动时或首次进入倒数日页时调用 `notificationManager.requestEnableNotification()` 引导用户开启通知权限（可选体验优化，不阻塞 Step A）。
> 4. **验收标准**：QA 在通知权限**关闭**状态下新建 + 编辑各 5 次，全部保存成功、零重复、零失败 toast。

> **BUG-004 根因（QA 已定位到行，仅供主程序参考，QA 不改码）**
> 1. `pages/home/HomePage.ets:18` `private vm = homeVM` —— vm 是外部 `@ObservedV2` 单例，其字段为 `@Trace`。`@Trace` 变化只精确刷新「build 中**直接读取**该属性」的 UI 节点。
> 2. 宠物区（`HomePage.ets:88/92/96/100/104`）写法是 `Text(this.vm.petEmoji)`、`this.vm.streakDays` —— **直接读取**，依赖建立成功 → 数据到达即刷新 ✅。
> 3. 三卡（`HomePage.ets:168/173/178` 与 `186/188/190`）走 `this.countdownMain()` / `this.focusMain()` / `this.billMain()` 三个 **private 普通方法**（定义在 30/41/49 行），`@Trace` 属性在方法内部被间接读取 → **依赖未建立** → 数据到达后不触发重算 ❌。
> 4. 于是形成竞态：`HomePage.aboutToAppear:24` 的 `vm.load()` 若在**首帧渲染之前**完成，build 首次执行即读到新值 → 正常（约 72%）；若在**首帧之后**完成 → 三卡永久停在初值（约 28%）。这解释了「宠物对、三卡空」的自相矛盾与不可自愈。
> 5. **排除项**：抓 hilog 全量日志，**无** `HomePage` 域「首页加载失败」error（`aboutToAppear` 的 `.catch` 未触发）→ `load()` 未抛异常、DB 数据正常，**非数据层问题**，纯 UI 依赖收集问题。`DatabaseHelper.get()` 未初始化会 throw（`DatabaseHelper.ets:94`）+ `EntryAbility.onCreate:21` 的 `init()` 未 await、`onWindowStageCreate:58` 的 `loadContent` 不等 DB 就绪，属并存隐患但**本 Bug 已排除该路径**。
> **建议修法**：把 `countdownMain()` / `focusMain()` / `billMain()` 三个 private 方法改为 `@Computed get` 计算属性——同文件 `HomePage.ets:17` 的 `@Computed get winWidthVp()` 就是现成的正确写法，改动小、无需动 VM。
> **扩散面（QA 静态判定）**：同构风险仅 `pages/pomodoro/PomodoroStatsPage.ets:15`（`private vm = pomodoroVM` + `weekDayNames()`/`maxWeekValue()`/`barHeightPercent()`），建议一并改。已排除安全：`AccountReportPage` / `CountdownDetailPage` / `PomodoroTimerPage` 均为组件自身 `@Local`（整体重绘）——其中 PomodoroTimerPage 已真机实测倒计时正常跳动（25:00→24:55→24:44→24:33）。

> **主程序修复记录（2026-08-02，不自闭环，待 QA 复验）**：已将 `HomePage.ets` 三卡 `countdownMain()/focusMain()/billMain()` 及 `isLg()` 由 private 方法改为 `@Computed get`（`resourceManager` 走 `AppContextHolder.get() ?? getContext(this)` 兜底，与 `MainPage.ets:96/109` 同款）；并依 QA 建议对同根因 `PomodoroStatsPage.ets` 的 `maxWeekValue()/barHeightPercent(idx)`（经私有方法读 `vm.weekDays`）做加固——改为在 `chart()` @Builder 内直接读取 `vm.weekDays` 计算，移除两私有方法。两文件静态自检 06 §2 禁令 1–10 全过。验收：QA 复跑 20 次冷启动零失败（T19）。

## 环境阻塞项（不计产品 Bug，但卡验证进度）

| 编号 | 端 | 现象 | 根因（已实测确认） | 影响 | 状态 | 指派给 |
|---|---|---|---|---|---|---|
| ENV-001 | 手机（连带平板/手表） | 真机安装报 `code:9568423 device is unauthorized` | 手机 UDID `DC1C189C…D87FC` 不在调试 profile 的 `debug-info.device-ids`（原仅 5 台旧设备，无本机）；hdc 已识别设备 `7ST0226414020964`、bundleName/证书有效期/类型均正常 → 纯签名授权问题，非代码缺陷 | T5 手机回归（8/6）曾完全阻塞 | ✅ **已解除（2026-08-01 22:49）**：老板按方案 A 走 DevEco 自动签名重下发；**QA 复核通过**——新 p7b 设备数 5→6，`DC1C189C…D87FC` 已在 `device-ids` 内。T5 手机回归解封可开跑。⚠️ **平板/手表 UDID 仍未注册，T8/T9 上真机时会复现同错**（模拟器/Previewer 不受影响），处置见 `work/docs/排障_真机安装失败_UDID未授权.md` §五 | 已闭环（QA 复核） |

## 观察项（不计 Bug，供决策）

| 编号 | 说明 | 建议 |
|---|---|---|
| OBS-001 | fontSize/间距等数字尺寸普遍未走 `$r('app.float.xxx')`，严格按 06 §2-5 属违规，但全仓量大、W5 已定型 | 建议老板定口径：MVP 豁免存量、新代码（C1-C3 特色）强制 `$r()`；避免冻结期大改引入回归 |
| OBS-002 | repository 层用 try/finally 关资源、异常上抛，catch 兜底在 viewmodel/pages/service 层（已抽查覆盖广泛）；个别 VM（HomeViewModel/PomodoroViewModel）自身无 catch，依赖页面层兜底 | 架构成立，不改；T5/T8 回归时重点观察 DB 异常场景是否有 toast 而非崩溃 |
| OBS-003 | 走查通过项：any/unknown 零命中 ✅ 解构零命中 ✅ 页面直连 DB 零命中（entry+wearable 全部走 repository）✅ exp 联动仅在两个 PetEngine.ets ✅ V1 装饰器全仓仅 BUG-001 一处 ✅ toast 文案全部 `$r()` ✅ | — |
